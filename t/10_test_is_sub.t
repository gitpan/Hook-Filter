#!/usr/local/bin/perl
#################################################################
#
#   $Id: 10_test_is_sub.t,v 1.1 2006/01/27 06:56:16 erwan Exp $
#
#   @author       erwan lemonnier
#   @description  test is_sub from Hook::Filter
#   @system       pluto
#   @function     base
#

package MyTest;

sub mysub1 { return 1; };
sub mysub2 { return 1; };
sub mysub3 { return 1; };
sub mysub4 { return 1; };
sub mysub5 { return 1; };
sub mysub6 { return 1; };

1;

package main;

use strict;
use warnings;
use Data::Dumper;
use Test::More;

BEGIN {
    eval "use Module::Pluggable"; plan skip_all => "Module::Pluggable required for testing Hook::Filter" if $@;
    eval "use File::Spec"; plan skip_all => "File::Spec required for testing Hook::Filter" if $@;
    plan tests => 14;

    use_ok('Hook::Filter::Hook');
    use_ok('Hook::Filter::Rule');
}

my($hook,$rule);

sub mysub1 { return 1; };
sub mysub2 { return 1; };
sub mysub3 { return 1; };
sub mysub4 { return 1; };
sub mysub5 { return 1; };
sub mysub6 { return 1; };

# test match only function name
$hook = Hook::Filter::Hook->new();
$rule = Hook::Filter::Rule->new("is_sub('main::mysub1');");
$hook->register_rule($rule);
$hook->filter_sub('main::mysub1');
$hook->filter_sub('main::mysub2');
$hook->filter_sub('MyTest::mysub1');
$hook->filter_sub('MyTest::mysub2');

is(mysub1,1,"main::sub1 matches string");
is(mysub2,undef,"main::sub2 does not match string");
is(MyTest::mysub1,undef,"MyTest::sub1 does not match string");
is(MyTest::mysub2,undef,"MyTest::sub2 does not match string");

# test match function name and package name
$hook = Hook::Filter::Hook->new();
$rule = Hook::Filter::Rule->new("is_sub('MyTest::mysub3');");
$hook->register_rule($rule);
$hook->filter_sub('main::mysub3');
$hook->filter_sub('main::mysub4');
$hook->filter_sub('MyTest::mysub3');
$hook->filter_sub('MyTest::mysub4');

is(mysub3,undef,"main::sub3 does not match string");
is(mysub4,undef,"main::sub4 does not match string");
is(MyTest::mysub3,1,"MyTest::sub3 matches string");
is(MyTest::mysub4,undef,"MyTest::sub4 does not match string");

# test match regexp
$hook = Hook::Filter::Hook->new();
$rule = Hook::Filter::Rule->new('is_sub(qr{My.*sub[56]$})');
$hook->register_rule($rule);
$hook->filter_sub('main::mysub5');
$hook->filter_sub('main::mysub6');
$hook->filter_sub('MyTest::mysub5');
$hook->filter_sub('MyTest::mysub6');

is(mysub5,undef,"main::sub5 does not match string");
is(mysub6,undef,"main::sub6 does not match string");
is(MyTest::mysub5,1,"MyTest::sub5 matches string");
is(MyTest::mysub6,1,"MyTest::sub6 matches string");
