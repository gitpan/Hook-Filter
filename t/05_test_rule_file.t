#!/usr/local/bin/perl
#################################################################
#
#   $Id: 05_test_rule_file.t,v 1.1 2006/01/27 06:56:16 erwan Exp $
#
#   @author       erwan lemonnier
#   @description  test using a rule file with Hook::Filter
#   @system       pluto
#   @function     base
#

#
# test package
#

# putting package declaration before main:: is voluntary. want to test that
# Hook::Filter does hook the same subs here than in main
package MyTest;

use strict;
use warnings;
use Hook::Filter;

sub mylog1 { return 1; };
sub mylog2 { return 1; };
sub mylog3 { return 1; };

1;

package MyTest::Child;

use strict;
use warnings;
use Hook::Filter;

sub mylog1 { return 1; };
sub mylog2 { return 1; };
sub mylog3 { return 1; };

1;

#
# main code
#

package main;

use strict;
use warnings;
use Data::Dumper;
use Test::More;

sub mylog1 { return 1; };
sub mylog2 { return 1; };
sub mylog3 { return 1; };

my $rule_file;

BEGIN {
    eval "use Module::Pluggable"; plan skip_all => "Module::Pluggable required for testing Hook::Filter" if $@;
    eval "use File::Spec"; plan skip_all => "File::Spec required for testing Hook::Filter" if $@;
    plan tests => 10;

    $rule_file = "./tmp_rules_file";

    if (-e $rule_file) {
	`rm $rule_file`;
    }
    `touch $rule_file`;
    `echo "# a commentar" >> $rule_file`;
    `echo "     # an other commentar" >> $rule_file`;
    `echo "     " >> $rule_file`;
    `echo "0" >> $rule_file`;
    `echo "is_sub('MyTest::mylog1')" >> $rule_file`;
    `echo "is_sub('main::mylog2')" >> $rule_file`;
    `echo " # yet an other commentar" >> $rule_file`;
    `echo "is_sub(qr{mylog3\$})" >> $rule_file`;
    `echo "is_sub(qr{Child.*[23]\$})" >> $rule_file`;
    
    use_ok('Hook::Filter','rules',$rule_file,'hook',['mylog1','mylog2','mylog3']);
}

# now let's test that the rules in $rule_file were indeed parsed
is(mylog1,undef,"main::mylog1 ok");
is(mylog2,1,"main::mylog2 ok");
is(mylog3,1,"main::mylog3 ok");

is(MyTest::mylog1,1,"MyTest::mylog1 ok");
is(MyTest::mylog2,undef,"MyTest::mylog2 ok");
is(MyTest::mylog3,1,"MyTest::mylog3 ok");

is(MyTest::Child::mylog1,undef,"MyTest::Child::mylog1 ok");
is(MyTest::Child::mylog2,1,"MyTest::Child::mylog2 ok");
is(MyTest::Child::mylog3,1,"MyTest::Child::mylog3 ok");

`rm $rule_file`;
