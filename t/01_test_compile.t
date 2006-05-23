#!/usr/local/bin/perl
#################################################################
#
#   $Id: 01_test_compile.t,v 1.2 2006/04/26 21:49:40 erwan Exp $
#
#   @author       erwan lemonnier
#   @description  test that all modules under Hook::Filter do compile
#   @system       pluto
#   @function     base
#

use strict;
use warnings;
use Data::Dumper;
use Test::More;
use lib "../lib/";

BEGIN { 
    eval "use Module::Pluggable"; plan skip_all => "Module::Pluggable required for testing Hook::Filter" if $@;

    plan tests => 3;

    use_ok('Hook::Filter::Rule');
    use_ok('Hook::Filter::Hook');
    use_ok('Hook::Filter','hook',[]);
};
