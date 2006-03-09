#!/usr/local/bin/perl
#################################################################
#
#   $Id: 12_test_from_pkg.t,v 1.1 2006/01/27 06:56:16 erwan Exp $
#
#   @author       erwan lemonnier
#   @description  test from_sub from Hook::Filter and flush_rules from Hook::Filter::Hook
#   @system       pluto
#   @function     base
#

package MyTest1;

sub mytest1 { return 1; };
sub mysub1 { return mytest1(); };

1;

package MyTest1::Child;

sub mytest1 { return 1; };
sub mysub1 { return mytest1(); };

1;

package main;

use strict;
use warnings;
use Data::Dumper;
use Test::More;

BEGIN {
    eval "use Module::Pluggable"; plan skip_all => "Module::Pluggable required for testing Hook::Filter" if $@;
    eval "use File::Spec"; plan skip_all => "File::Spec required for testing Hook::Filter" if $@;
    plan tests => 11;

    use_ok('Hook::Filter::Hook');
    use_ok('Hook::Filter::Rule');
}

my($hook,$rule);

sub mytest1 { return 1; };
sub mysub1 { return mytest1(); };

# test match package name
$hook = Hook::Filter::Hook->new();
$rule = Hook::Filter::Rule->new("from_pkg('MyTest1');");
$hook->register_rule($rule);
$hook->filter_sub('main::mytest1');
$hook->filter_sub('MyTest1::mytest1');
$hook->filter_sub('MyTest1::Child::mytest1');

is(mysub1,undef,                 "main::mysub1 does not match string");
is(MyTest1::mysub1,1,            "MyTest1::mysub1 does match string");
is(MyTest1::Child::mysub1,undef, "MyTest1::Child::mysub1 does not match string");

# test match regexp
$hook->flush_rules();
$rule = Hook::Filter::Rule->new('from_pkg(qr{^MyTest1})');
$hook->register_rule($rule);

is(mysub1,undef,             "main::mysub1 does not match string (after flush/reload)");
is(MyTest1::mysub1,1,        "MyTest1::mysub1 does match string (after flush/reload)");
is(MyTest1::Child::mysub1,1, "MyTest1::Child::mysub1 does match string (after flush/reload)");

# test flush_rules
$hook->flush_rules();
$rule = Hook::Filter::Rule->new('1');
$hook->register_rule($rule);

is(mysub1,1,                 "main::mysub1 does match string (after new flush/reload)");
is(MyTest1::mysub1,1,        "MyTest1::mysub1 does match string (after new flush/reload)");
is(MyTest1::Child::mysub1,1, "MyTest1::Child::mysub1 does match string (after new flush/reload)");

