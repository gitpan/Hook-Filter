#!/usr/local/bin/perl
#################################################################
#
#   $Id: 01_test_compile.t,v 1.1 2006/01/27 06:56:16 erwan Exp $
#
#   @author       erwan lemonnier
#   @description  test that all modules under Hook::Filter do compile
#   @system       pluto
#   @function     base
#

use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 3;

BEGIN { 
    use_ok('Hook::Filter::Rule');
    use_ok('Hook::Filter::Hook');
    use_ok('Hook::Filter','hook',[]);
};
