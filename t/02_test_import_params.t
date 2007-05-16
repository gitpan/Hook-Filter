#################################################################
#
#   $Id: 02_test_import_params.t,v 1.3 2007/05/16 14:09:09 erwan_lemonnier Exp $
#
#   test Hook:Filter's import parameters
#

use strict;
use warnings;
use Data::Dumper;
use Test::More;
use lib "../lib/";

#
# inspired by Test::More's use_ok
#

my $count = 0;

sub my_use_ok {
    my($flush,@imports) = @_;
    @imports = () unless @imports;

    $count++;
    my $pkg = "bob".$count;

    local($@,$!);   # eval sometimes interferes with $!

    eval <<TEST;
package $pkg;
use Hook::Filter \@imports;
if ($flush) {
    Hook::Filter::_test_import_flush;
}
TEST

    if (!$@) {
	return "";
    } else {
	return $@;
    }
}

# do tests
BEGIN {
    eval "use Module::Pluggable"; plan skip_all => "Module::Pluggable required for testing Hook::Filter" if $@;
    eval "use File::Spec"; plan skip_all => "File::Spec required for testing Hook::Filter" if $@;
    plan tests => 10;

    my $err;

    #
    # test 'rules_path'
    #

    # rules_path undefined
    $err = my_use_ok(1,'rules',undef);
    ok($err =~ /invalid parameter:.*'rules'.*was undef/i,"use with 'rules' => undef");

    # rules_path an array of non scalar
    $err = my_use_ok(1,'rules',[ [1,2,3],"bob"]);
    ok($err =~ /invalid parameter:.*'rules'.*should be a string, but was \[/i,"use with 'rules' => array of non scalar");

    # try redefining rules_path
    $err = my_use_ok(0,'rules',"/tmp/var1");
    ok($err eq "","use with 'rules' once");

    $err = my_use_ok(0,'rules',"/tmp/var2");
    ok($err =~ /invalid parameter:.*'rules'.*cannot be used more than once.*/i,"use with 'rules', trying to redefine search path");

    #
    # test 'hook'
    #

    # hook undefined
    $err = my_use_ok(1,'hook',undef);
    ok($err =~ /invalid parameter:.*hook.*was undef/i,"use with hook undef");

    # hook not scalar nor array
    $err = my_use_ok(1,'hook',{a=>1});
    ok($err =~ /invalid parameter:.*hook.*, but was/i,"use with hook neither scalar nor array");

    # hook array of non scalar
    $err = my_use_ok(1,'hook',[{a=>1}]);
    ok($err =~ /invalid parameter:.*hook.*, but was/i,"use with hook array of non scalar");

    # hook an array of scalar
    $err = my_use_ok(1,'hook',["sub1","sub2"]);
    ok($err eq "","use with hook a valid array of scalar");

    # hook a scalar
    $err = my_use_ok(0,'hook',"sub3");
    ok($err eq "","use with hook a valid scalar [$err]");

    # no params = ok
    $err = my_use_ok(0);
    ok($err eq "","use without parameters [$err]");
}
