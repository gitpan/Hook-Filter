#################################################################
#
#   $Id: 01_test_compile.t,v 1.5 2007/05/16 15:44:21 erwan_lemonnier Exp $
#
#   test that all modules compile
#

use strict;
use warnings;
use Data::Dumper;
use Test::More;
use lib "../lib/";

BEGIN {
    eval "use Module::Pluggable"; plan skip_all => "Module::Pluggable required for testing Hook::Filter" if $@;

    plan tests => 5;

    use_ok('Hook::Filter::Plugins::Library');
    use_ok('Hook::Filter::Rule');
    use_ok('Hook::Filter::RulePool');
    use_ok('Hook::Filter::Hooker');
    use_ok('Hook::Filter','hook',[]);
};
