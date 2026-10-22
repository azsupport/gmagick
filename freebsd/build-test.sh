#!/bin/sh
# build-test.sh - build gmagick as a shared module (phpize) against the PHP builds
# of azsupport/php-src on FreeBSD, and check that it loads and writes a PNG.
#
# Usage (inside the FreeBSD VM of .github/workflows/freebsd.yml, or by hand):
#   sh freebsd/build-test.sh --deps <version>...   install the packages
#   sh freebsd/build-test.sh [--tests] <version>... build and check, e.g. 7.4 8.4
#
# For each version, dist/php-<version>-fbsd-latest.tar.xz (the release tarball of
# azsupport/php-src) is built with --disable-all into /usr/local/php<XY>-gm, then
# this source tree is built with its phpize and php-config. --tests also runs the
# .phpt tests of gmagick. Results go to results/<version>/ (summary.txt, the logs).
#
# Exit status: 0 every version built and passed the smoke check, 1 otherwise.

set -u
top="$(cd "$(dirname "$0")/.." && pwd)"
dist="$top/dist"
results="$top/results"
ncpu="$(sysctl -n hw.ncpu 2>/dev/null || echo 2)"

say() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }

if [ "${1:-}" = "--deps" ]; then
    shift
    env ASSUME_ALWAYS_YES=yes pkg install -y pkgconf GraphicsMagick autoconf
    exit $?
fi
tests=0
if [ "${1:-}" = "--tests" ]; then tests=1; shift; fi
[ $# -gt 0 ] || { sed -n 's/^# \{0,1\}//; 5,7p' "$0" >&2; exit 2; }

rc=0
for t in "$@"; do
    out="$results/$t"
    rm -rf "$out"; mkdir -p "$out"
    sum="$out/summary.txt"
    v="$(echo "$t" | tr -d .)"
    prefix="/usr/local/php$v-gm"
    {
        echo "target:   $t"
        echo "host:     $(uname -sr), $(cc --version | head -1)"
        echo "GraphicsMagick: $(GraphicsMagick-config --version 2>/dev/null || echo '?')"
    } > "$sum"

    tarball="$dist/php-$t-fbsd-latest.tar.xz"
    if [ ! -f "$tarball" ]; then
        echo "result:   FAIL (no tarball $tarball)" >> "$sum"; rc=1; continue
    fi
    say "$t: build PHP (--disable-all) into $prefix"
    src="$out/php-src"
    mkdir -p "$src" && tar -xf "$tarball" -C "$src" --strip-components 1
    if ! (cd "$src" && ./configure --disable-all --disable-cgi --disable-phpdbg --prefix="$prefix" \
            > "$out/php-configure.log" 2>&1 && make -j"$ncpu" > "$out/php-make.log" 2>&1 \
            && make install > "$out/php-install.log" 2>&1); then
        echo "result:   FAIL (PHP build, see php-*.log)" >> "$sum"
        tail -n 20 "$out/php-make.log" "$out/php-configure.log" 2>/dev/null | cut -c1-240 > "$out/errors.txt"
        rc=1; continue
    fi
    echo "php:      $("$prefix/bin/php" -n -v | head -1)" >> "$sum"

    say "$t: phpize, configure, make gmagick"
    bld="$out/gmagick"
    mkdir -p "$bld"
    (cd "$top" && tar --exclude ./dist --exclude ./results --exclude ./.git -cf - .) | tar -xf - -C "$bld"
    if ! (cd "$bld" && "$prefix/bin/phpize" > "$out/phpize.log" 2>&1 \
            && ./configure --with-php-config="$prefix/bin/php-config" --with-gmagick=/usr/local \
                > "$out/configure.log" 2>&1 \
            && make -j"$ncpu" > "$out/make.log" 2>&1); then
        echo "result:   FAIL (gmagick build, first errors in errors.txt)" >> "$sum"
        { grep -E ' error:|Error [0-9]+|undefined' "$out/make.log" "$out/configure.log" 2>/dev/null | head -n 30
          tail -n 15 "$out/configure.log" 2>/dev/null; } | sed 's#.*/gmagick/##' | cut -c1-240 > "$out/errors.txt"
        rc=1; continue
    fi
    echo "make:     $(grep -c 'warning:' "$out/make.log") warnings" >> "$sum"

    so="$bld/modules/gmagick.so"
    smoke="$("$prefix/bin/php" -n -d "extension=$so" -r '
        $g = new Gmagick();
        $g->newImage(8, 8, "red", "png");
        echo phpversion("gmagick"), " ", substr($g->getImageBlob(), 1, 3);' 2>&1)"
    echo "smoke:    $smoke" >> "$sum"
    case "$smoke" in
        *" PNG") ;;
        *) echo "result:   FAIL (smoke check)" >> "$sum"; rc=1; continue ;;
    esac

    if [ "$tests" = 1 ]; then
        say "$t: run-tests"
        # run-tests.php directly (phpize copies it here): "make test" under BSD make
        # handed it a broken argument list and only printed its usage.
        (cd "$bld" && env NO_INTERACTION=1 REPORT_EXIT_STATUS=0 TEST_PHP_EXECUTABLE="$prefix/bin/php" \
            "$prefix/bin/php" -n run-tests.php -q -n -d "extension=$so" tests > "$out/tests.log" 2>&1 < /dev/null)
        # One result per line: colours, carriage returns and "TEST n/m [...]" progress
        # removed (run-tests rewrites its progress line with \r).
        tr -d '\033' < "$out/tests.log" | sed -E 's/\[[0-9;]*m//g' | tr '\r' '\n' |
            sed -E 's/^TEST [0-9]+\/[0-9]+ \[[^]]*\] *//' > "$out/tests.lines"
        grep -E '^FAIL ' "$out/tests.lines" > "$out/tests.txt"
        if grep -q -E '^Tests passed' "$out/tests.lines"; then
            echo "tests:    $(grep -E '^(Number of tests|Tests (skipped|warned|failed|passed))' "$out/tests.lines" |
                tr -s ' ' | sed 's/ :/:/' | tr '\n' ',' | sed 's/,$//; s/,/, /g')" >> "$sum"
        else
            echo "tests:    $(grep -c -E '^PASS ' "$out/tests.lines") passed, $(grep -c -E '^FAIL ' "$out/tests.lines") failed, $(grep -c -E '^SKIP ' "$out/tests.lines") skipped; no run-tests summary, end of the log in tests-tail.txt" >> "$sum"
            tail -n 15 "$out/tests.log" | cut -c1-200 > "$out/tests-tail.txt"
        fi
    fi
    echo "result:   OK" >> "$sum"
    say "$t: OK ($smoke)"
done
exit "$rc"
