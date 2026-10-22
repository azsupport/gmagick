--TEST--
Test setfillopacity, getfillopacity
--SKIPIF--
<?php
/* $Id: gmagickdraw-007-setfillopacity_getfillopacity.phpt 280206 2009-05-09 18:22:48Z vito $ */
if(!extension_loaded('gmagick')) die('skip');
?>
--FILE--
<?php
$gd = new GMagickDraw();
$gd->setFillOpacity(0.8);
// GraphicsMagick 1.3.47 rebuilt the drawing wand on magick/draw.c ("drawing_wand.c
// functions which duplicate code in magick/draw.c are gutted"): since then the
// opacity that was set comes back; before, the getter returned 1 - opacity.
$gm = new Gmagick();
$version = $gm->getVersion();
preg_match('/GraphicsMagick (\d+\.\d+\.\d+)/', $version['versionString'], $m);
$expected = version_compare($m[1], '1.3.47', '>=') ? 0.8 : 0.2;
var_dump(abs($gd->getFillOpacity() - $expected) < 0.0001);
?>
--EXPECT--
bool(true)
