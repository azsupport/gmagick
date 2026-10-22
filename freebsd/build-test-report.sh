#!/bin/sh
# build-test-report.sh - turn results/<version>/ of freebsd/build-test.sh into the
# job log, the job summary and one annotation per version (notice when the module
# built and passed the smoke check, error when not).
#
# Usage: sh freebsd/build-test-report.sh [results-dir]   (default: results)

set -u
res="${1:-results}"
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"
escape() { sed 's/%/%25/g; s/\r/%0D/g' | awk '{ printf "%s%%0A", $0 }'; }

[ -d "$res" ] || { echo "::error title=build-test::no results in $res"; exit 1; }
rc=0
for dir in "$res"/*/; do
    [ -f "$dir/summary.txt" ] || continue
    target="$(basename "$dir")"
    {
        cat "$dir/summary.txt"
        if [ -s "$dir/errors.txt" ] && ! grep -q '^result: *OK' "$dir/summary.txt"; then
            echo "first errors:"
            head -n 30 "$dir/errors.txt"
        fi
        if [ -s "$dir/tests.txt" ]; then
            echo "failed tests ($(wc -l < "$dir/tests.txt" | tr -d ' ')):"
            head -n 40 "$dir/tests.txt" | cut -c1-160
        fi
        if [ -s "$dir/tests-tail.txt" ]; then
            echo "end of the make test output:"
            cat "$dir/tests-tail.txt"
        fi
    } > "$dir/report.txt"
    echo "==================== $target"
    cat "$dir/report.txt"
    if grep -q '^result: *OK' "$dir/summary.txt"; then level=notice; else level=error; rc=1; fi
    printf '::%s title=gmagick on PHP %s::%s\n' "$level" "$target" "$(head -c 3800 "$dir/report.txt" | escape)"
    { echo "### PHP $target"; echo; echo '```'; cat "$dir/report.txt"; echo '```'; echo; } >> "$summary"
    # the diffs of the failed tests in an annotation of their own (warning: notices
    # and warnings are counted separately, 10 of each per step)
    if [ -s "$dir/tests-diff.txt" ]; then
        printf '::warning title=gmagick on PHP %s, failed tests::%s\n' "$target" "$(head -c 3800 "$dir/tests-diff.txt" | escape)"
        { echo "#### PHP $target, failed tests"; echo; echo '```'; cat "$dir/tests-diff.txt"; echo '```'; echo; } >> "$summary"
    fi
done
exit "$rc"
