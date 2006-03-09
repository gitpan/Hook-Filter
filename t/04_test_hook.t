#!/usr/local/bin/perl
#################################################################
#
#   $Id: 04_test_hook.t,v 1.1 2006/01/27 06:56:16 erwan Exp $
#
#   @author       erwan lemonnier
#   @description  test Hook::Filter::Hook
#   @system       pluto
#   @function     base
#

#
# test package
#

package MyTest;

use strict;
use warnings;
use Hook::Filter::Hook;

sub dobido_test {
    return (get_caller_package,get_caller_file,get_caller_line,get_caller_subname,get_subname,get_arguments);
}

sub dobido {
    return dobido_test('ab','cd');
}

1;

#
# main code
#

package main;

use strict;
use warnings;
use Data::Dumper;
use Test::More;

BEGIN {
    eval "use Module::Pluggable"; plan skip_all => "Module::Pluggable required for testing Hook::Filter" if $@;
    eval "use File::Spec"; plan skip_all => "File::Spec required for testing Hook::Filter" if $@;
    plan tests => 36;

    use_ok('Hook::Filter::Hook');
    use_ok('Hook::Filter::Rule');
}

sub main_test {
    return (get_caller_package,get_caller_file,get_caller_line,get_caller_subname,get_subname,get_arguments);
}

my $tmpfil = "/tmp/testfile_hook_filter";

my $hook = Hook::Filter::Hook->new();

my $rule = Hook::Filter::Rule->new("1;");

# test argument checks for register_rule
eval { $hook->register_rule(); };
ok(($@ =~ /register_rule expects one instance of hook::filter::rule/i),"register_rule with too few args");
eval { $hook->register_rule(undef); };
ok(($@ =~ /register_rule expects one instance of hook::filter::rule/i),"register_rule with undef");
eval { $hook->register_rule("abc"); };
ok(($@ =~ /register_rule expects one instance of hook::filter::rule/i),"register_rule with wrong datatype");
eval { $hook->register_rule($rule,1); };
ok(($@ =~ /register_rule expects one instance of hook::filter::rule/i),"register_rule with right args but too many");

$hook->register_rule($rule);

# test function
my $TEST_RAN = 0;

sub test {
    my @args = @_;
    $TEST_RAN = 1;
    if (wantarray) {
	return (@args,1,2);
    } else {
	return join(":",@args);
    }
}

# test argument checks for filter_sub
eval { $hook->filter_sub([1,0])};
ok(($@ =~ /filter_sub expects a subroutine name/i),"filter_sub with subroutine an array ref");

eval { $hook->filter_sub({a=>1})};
ok(($@ =~ /filter_sub expects a subroutine name/i),"filter_sub with pkg a hash ref");

eval { $hook->filter_sub("main","test","")};
ok(($@ =~ /filter_sub expects a subroutine name/i),"filter_sub with too many args");

eval { $hook->filter_sub()};
ok(($@ =~ /filter_sub expects a subroutine name/i),"filter_sub with too few args");

eval { $hook->filter_sub("main")};
ok(($@ =~ /is not a valid subroutine name/i),"filter_sub with invalid subroutine name");

eval { $hook->filter_sub("main::bob"); };
ok(!$@,"filter_sub with correct arg");

$hook->filter_sub("main::test");

# test filter when rules are true
my $res1;
$TEST_RAN = 0;
eval { $res1 = test('a','b','c'); };
ok(!$@,"calling test function in scalar context, rules true [$@]");
is($TEST_RAN,1,"test function was executed");
is($res1,"a:b:c","test function result");

my @res2;
$TEST_RAN = 0;
eval { @res2 = test('a','b','c'); };
ok(!$@,"calling test function in array context, rules true");
is($TEST_RAN,1,"test function was executed");
is_deeply(\@res2,['a','b','c',1,2],"test function result");

# test filter when rules are false
$hook = Hook::Filter::Hook->new();
$rule = Hook::Filter::Rule->new("0;");
$hook->register_rule($rule);
$hook->filter_sub("main::test");

$TEST_RAN = 0;
eval { $res1 = test('a','b','c'); };
ok(!$@,"calling test function in scalar context, rules false");
is($TEST_RAN,0,"test function was skipped");
ok(!defined $res1,"test function result");

$TEST_RAN = 0;
eval { @res2 = test('a','b','c'); };
ok(!$@,"calling test function in array context, rules false");
is($TEST_RAN,0,"test function was skipped");
is_deeply(\@res2,[],"test function result");

# test that Hook::Filter::Hook sets its global variables right
$rule = Hook::Filter::Rule->new("1;");
$hook->flush_rules();
$hook->register_rule($rule);
$hook->filter_sub("MyTest::dobido_test");
$hook->filter_sub("main::main_test");

# ad once more, just to improve coverage :)
$hook->filter_sub("main::main_test");

my ($pkg,$file,$line,$subname,$myname,@args) = MyTest::dobido();
is($pkg,"MyTest","checking caller package");
ok($file =~ /04_test_hook.t$/,"checking caller file");
is($line,27,"checking caller line");
is($subname,"MyTest::dobido","checking caller subname");
is($myname,'MyTest::dobido_test',"checking own name");
is_deeply(\@args,['ab','cd'],"checking own arguments");

($pkg,$file,$line,$subname,$myname,@args) = main_test(1,2,3,4);
is($pkg,"main","checking caller package");
ok($file =~ /04_test_hook.t$/,"checking caller file");
is($line,159,"checking caller line");
is($subname,"","checking caller subname");
is($myname,'main::main_test',"checking own name");
is_deeply(\@args,[1,2,3,4],"checking own arguments");





