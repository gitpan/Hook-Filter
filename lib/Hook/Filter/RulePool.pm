#################################################################
#
#   Hook::Filter::RulePool - A pool of filter rules
#
#   $Id: RulePool.pm,v 1.1 2007/05/16 13:31:36 erwan_lemonnier Exp $
#
#   070516 erwan Started
#

package Hook::Filter::RulePool;

use 5.006;
use strict;
use warnings;
use Carp qw(croak);
use Data::Dumper;
use Hook::Filter::Rule;

use base qw(Exporter);

our @EXPORT = ();
our @EXPORT_OK = ('get_rule_pool');


# the filter rules
my @rules;

#---------------------------------------------------------------
#
#   A singleton pattern with lazy initialization and embedded constructor
#

my $pool;

sub get_rule_pool {
    if (!defined $pool) {
	$pool = bless({},__PACKAGE__);
    }
    return $pool;
}

# make sure no one calls the constructor
sub new {
    croak "use get_pool() instead of new()";
}

#----------------------------------------------------------------
#
#   add_rule - add a rule to the pool
#

sub add_rule {
    my ($self,$obj) = @_;

    if (!defined $obj || (ref $obj ne "Hook::Filter::Rule" && ref \$obj ne "SCALAR") || scalar @_ != 2) {
	shift @_;
	croak "invalid parameters: Hook::Filter::RulePool->add_rule expects an instance of Hook::Filter::Rule or a rule string, and not [".Dumper(@_)."]";
    }

    if (ref \$obj eq "SCALAR") {
	# $obj is just a string containing a rule in text form
	my $rule = new Hook::Filter::Rule($obj);

	my ($pkg,$line) = (caller(0))[0,2];
	my $fnc = (caller(1))[3] || "main";
	$rule->source("added by ".$pkg."::".$fnc.", l.$line");

	push @rules, $rule;
    } else {
	# $obj is an instance of Hook::Filter::Rule
	push @rules, $obj;
    }

    return $self;
}

#----------------------------------------------------------------
#
#   flush_rules - remove all rules
#

sub flush_rules {
    @rules = ();
}

#----------------------------------------------------------------
#
#   get_rules - return all registered rules
#

sub get_rules {
    return @rules;
}

#----------------------------------------------------------------
#
#   eval_rules - eval all rules and return true if one is true or none is registered (fail safe)
#

sub eval_rules {
    my $self = shift;

    # if no rules are registered, default to true (allow call)
    return 1 if (!@rules);

    # evaluate all rules, until all one is found to be true or all are found to be false
    foreach my $rule (@rules) {
	return 1 if ($rule->eval());
    }

    return 0;
}

1;

__END__

=head1 NAME

Hook::Filter::RulePool - A pool of filter rules

=head1 SYNOPSIS

    use Hook::Filter::RulePool qw(get_rule_pool);

    my $pool = get_rule_pool();

    # add a rule that is always true
    $pool->add_rule("1");

    # add a more complex rule
    $pool->add_rule("arg(0) =~ /bob/ && from =~ /my_module/");

    if ($pool->eval_rules) {
        # call is allowed
    }

    $pool->flush_rules;

=head1 DESCRIPTION

Hook::Filter::RulePool contains all the filtering rules
eval-ed when each time a filtered subroutine is called.

Using Hook::Filter::RulePool, you can modify the filtering
rules at runtime. You can flush all rules or inject new
ones.

=head1 INTERFACE

=over 4

=item my $pool = B<get_rule_pool>();

Return the pool containing all known filtering rules.
C<get_rule_pool> is not exported by default so you have to import it explicitly:

    use Hook::Filter::RulePool qw(get_rule_pool);

=item $pool->B<eval_rules>()

Evaluate all the rules in the pool. If one evaluates to true, return
true. If none evaluates to true, return false. If the pool contained
no rules, return true.

=item $pool->B<add_rule>($rule)

Add the rule C<$rule> to the pool. C<$rule> must be an instance of Hook::Filter::Rule,
or a string representing valid perl code that evaluates to either true or false.

=item $pool->B<flush_rules>()

Remove all rules from the pool. All filtered calls will then be allowed by default.

=item $pool->B<get_rules>()

Return a list of all the rules registered in the pool, as strings.

=item B<new>()

Hook::Filter::RulePool follows the singleton pattern. Therefore, do not use C<new()>
to instantiate a rule pool, use C<get_rule_pool> instead.

=back

=head1 DIAGNOSTICS

=over 4

=item C<< $pool->add_rule() >> croaks if its argument is not an instance of Hook::Filter::Rule or a string.

=back

=head1 SEE ALSO

See Hook::Filter, Hook::Filter::Rule.

=head1 VERSION

$Id: RulePool.pm,v 1.1 2007/05/16 13:31:36 erwan_lemonnier Exp $

=head1 AUTHOR

Erwan Lemonnier C<< <erwan@cpan.org> >>

=head1 LICENSE

See Hook::Filter.

=cut
