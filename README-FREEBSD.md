# gmagick for FreeBSD

This fork of [vitoc/gmagick](https://github.com/vitoc/gmagick) (the PECL extension
for GraphicsMagick) builds gmagick as a shared module on FreeBSD 15 for the PHP
builds of [azsupport/php-src](https://github.com/azsupport/php-src): 5.6, 7.4, 8.1,
8.2, 8.3 and 8.4.

| Branch | gmagick | PHP |
|---|---|---|
| `fbsd` | 2.0.6RC1 plus the later commits of upstream master (PHP 8.1 fixes, 10.10.2021) | 7.4, 8.1, 8.2, 8.3, 8.4 |
| `fbsd-1.1` | 1.1.7RC3 (24.04.2015) | 5.6 |
| `master` | upstream, unchanged | |

gmagick has no stable release on PECL; 2.0.6RC1 (beta, 2021) is the newest, and
1.1.7RC3 is the release PECL names for PHP 5. The fixes of this fork are commits on
the `fbsd` branches; [`freebsd/build-test.sh`](freebsd/build-test.sh) and the
workflow [`freebsd.yml`](.github/workflows/freebsd.yml) build the module in a
FreeBSD 15.1 VM against each PHP version, load it and write a PNG.

The php-src fork also carries gmagick in `ext/` (`--with-gmagick=/usr/local` builds
it into PHP). This repository is for the other way: a shared module, loaded with
`extension=gmagick.so` only where it is needed.

## Build

gmagick and imagick cannot be loaded into one PHP together: GraphicsMagick and
ImageMagick have the same MagickWand function names. Load one of the two.

PHP 7.4 to 8.4 (here 8.1; for another version change `php81` in all lines):

```
pkg install -y GraphicsMagick
cd /root
fetch -o gmagick-fbsd.tar.gz https://github.com/azsupport/gmagick/archive/refs/heads/fbsd.tar.gz
tar xf gmagick-fbsd.tar.gz
cd gmagick-fbsd
/usr/local/php81/bin/phpize
./configure --with-php-config=/usr/local/php81/bin/php-config --with-gmagick=/usr/local
make -j`sysctl -n hw.ncpu`
make install
/usr/local/php81/bin/php --ini
```

Then add `extension=gmagick.so` to the `php.ini` that `php --ini` shows ("Loaded
Configuration File") and check:

```
/usr/local/php81/bin/php -m | grep gmagick
```

PHP 5.6: the same with the branch `fbsd-1.1`:

```
pkg install -y GraphicsMagick
cd /root
fetch -o gmagick-fbsd-1.1.tar.gz https://github.com/azsupport/gmagick/archive/refs/heads/fbsd-1.1.tar.gz
tar xf gmagick-fbsd-1.1.tar.gz
cd gmagick-fbsd-1.1
/usr/local/php56/bin/phpize
./configure --with-php-config=/usr/local/php56/bin/php-config --with-gmagick=/usr/local
make -j`sysctl -n hw.ncpu`
make install
/usr/local/php56/bin/php --ini
```

Restart php-fpm or Apache afterwards.
