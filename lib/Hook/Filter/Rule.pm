#################################################################
#
#   Hook::Filter::Rule - A filter rule
#
#   $Id: Rule.pm,v 1.2 2007/05/16 13:31:36 erwan_lemonnier Exp $
#
#   060301 erwan Created
#   070516 erwan Small POD and layout fixes
#

package Hook::Filter::Rule;

use 5.006;
use strict;
use warnings;
use Carp qw(croak);
use Data::Dumper;
use Symbol;
use Module::Pluggable search_path => ['Hook::Filter::Plugins'], require => 1;

#----------------------------------------------------------------
#
#   load test functions from plugins
#

INIT {

    my %TESTS;

    foreach my $plugin (Hook::Filter::Rule->plugins()) {
	my @tests = $plugin->register();
	# TODO: test that @tests is an array of strings. die with BUG:

	foreach my $test ($plugin->register()) {
	    if (exists $TESTS{$test}) {
		croak "invalid plugin function: test function [$test] exported by plugin [$plugin] is already exported by an other plugin.";
	    }
	    *{ qualify_to_ref($test,"Hook::Filter::Rule") } = *{ qualify_to_ref($test,$plugin) };
	    $TESTS{$test} = 1;
	}
    }
}

#----------------------------------------------------------------
#
#   new - build a new filter rule
#

sub new {
    my($pkg,$rule) = @_;
    $pkg = ref $pkg || $pkg;
    my $self = bless({},$pkg);

    if (!defined $rule || ref \$rule ne "SCALAR" || scalar @_ != 2) {
	shift @_;
	croak "invalid parameter: Hook::Filter::Rule->new expects one string describing a filter rule, but got [".Dumper(@_)."].";
    }

    $self->{RULE} = $rule;

    return $self;
}

#----------------------------------------------------------------
#
#   rule - accessor for the rule
#

sub rule {
    return $_[0]->{RULE};
}

#----------------------------------------------------------------
#
#   source - where the rule came from (used in error messages only)
#

sub source {
    my($self,$orig) = @_;

    if (!defined $orig || ref \$orig ne "SCALAR" || scalar @_ != 2) {
	shift @_;
	croak "invalid parameter: Hook::Filter::Rule->source expects one string, but got [".Dumper(@_)."].";
    }

    $self->{SOURCE} = $orig;
}

#----------------------------------------------------------------
#
#   eval - evaluate a rule. return either true or false
#

sub eval {
    my $self = shift;
    my $rule = $self->{RULE};

    my $res = eval $rule;
    if ($@) {
	# in doubt, let's assume we are not filtering anything, ie allow function calls as if we were not here
	warn "WARNING: invalid Hook::Filter rule [$rule] ".
	    ( (defined $self->{SOURCE})?"from file [".$self->{SOURCE}."] ":"")."caused error:\n".
	    "[".$@."]. Assuming this rule returned false.\n";
	return 1;
    }

    return ($res)?1:0;
}

1;

__END__

=head1 NAME

Hook::Filter::Rule - A hook filter rule

=head1 DESCRIPTION

WARNING: if you only intend to use Hook::Filter you won't have
to actually use Hook::Filter::Rule and can skip this page.

A filter rule is a perl expression that evaluates to either true or false.
Each time a call is made to one of the hooked subroutines all the filter
rules registered in Hook::Filter::Hook are evaluated, and if one of them returns
true, the hooked function is called. Otherwise it is skipped.

A rule is one line of valid perl code that usually combines boolean operators
with functions implemented in the modules under C<< Hook::Filter::Plugins:: >>.

=head1 SYNOPSIS

    use Hook::Filter::Rule;

    my $rule = Hook::Filter::Rule->new("1");
    if ($rule->eval) {
	print "just now, the rule [".$rule->rule."] is true\n";
    }

C<< $rule->eval() >> returns true when the filtered subroutines is called
from a package whose namespace starts with C<< Test:: >>.

=head1 INTERFACE

=over 4

=item B<new>(I<$rule>)

Return a new Hook::Filter::Rule created from the string I<$rule>. I<$rule>
is a valid line of perl code that should return either true or false when
eval-ed. It can use any of the functions exported by the plugins modules
located under C<< Hook::Filter::Plugins:: >>.

=item B<eval>()

Eval this rule. Depending on the context in which it is run (state of the
stack, caller, variables, etc.) C<< eval() >> will return either true or false.
If the rule dies/croaks/confesses while being eval-ed, a perl warning is
thrown and the rule is assumed to return true (fail-safe). The warning
contains details about the error message, the rule itself and where it
comes from (as specified with C<< source() >>).

=item B<source>(I<$message>)

Specify the origin of the rule. If the rule was parsed from a configuration file,
I<$message> should be the path to this file. This is used in the warning message
emitted when a rule fails during C<< eval() >>.

=item B<rule>()

Return the rule string (I<$rule> in C<< new() >>).

=back

=head1 DIAGNOSTICS

=over 4

=item C<< use Hook::Filter::Rule >> croaks if a plugin module tries to export a function name
that is already exported by an other plugin.

=item C<< Hook::Filter::Rule->new($rule) >> croaks if I<$rule> is not a scalar.

=item C<< $rule->eval() >> will emit a perl warning if the rule dies when eval-ed.

=item C<< $rule->source($text) >> croaks if I<$text> is not a scalar.

=back

=head1 BUGS AND LIMITATIONS

See Hook::Filter

=head1 SEE ALSO

See Hook::Filter, Hook::Filter::Hook, modules under Hook::Filter::Plugins::.

=head1 VERSION

$Id: Rule.pm,v 1.2 2007/05/16 13:31:36 erwan_lemonnier Exp $

=head1 AUTHOR

Erwan Lemonnier C<< <erwan@cpan.org> >>

=head1 LICENSE

See Hook::Filter.

=cut
