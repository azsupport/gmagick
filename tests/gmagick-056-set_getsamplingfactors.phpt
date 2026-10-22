--TEST--
Set, getsamplingfactors
--SKIPIF--
<?php
/* $Id: gmagick-056-set_getsamplingfactors.phpt 280206 2009-05-09 18:22:48Z vito $ */
if(!extension_loaded('gmagick')) die('skip');
?>
--FILE--
<?php
$gm = new Gmagick();
$gm->read("magick:rose");
$factors = $gm->setSamplingFactors(array(2, 2, 1, 1, 1, 1))->getSamplingFactors();
// GraphicsMagick (1.3.42 and later at least) stores the factors as horizontal x
// vertical pairs ("2x2,1x1,1x1") and gives back one value per pair, the horizontal
// one; the test used to expect every value back.
var_dump($factors == array(2, 1, 1) || $factors == array(2, 2, 1, 1, 1, 1));
?>
--EXPECT--
bool(true)
