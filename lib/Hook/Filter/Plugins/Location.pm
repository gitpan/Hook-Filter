#################################################################
#
#   Call::Filter::Plugin::Location - Functions for testing a subroutine location
#
#   $Id: Location.pm,v 1.1 2006/01/27 06:35:48 erwan Exp $
#
#   060302 erwan Created
#

package Hook::Filter::Plugins::Location;

use 5.006;
use strict;
use warnings;
use Carp qw(croak);
use Data::Dumper;
use Hook::Filter::Hook;

our $VERSION = '0.01';

#----------------------------------------------------------------
#
#   register - return a list of the tests available in this plugin
#

sub register {
    return qw(from_pkg from_sub is_sub);
}

#----------------------------------------------------------------
# 
#   _match_or_die - generic match function used by all test functions in here
#

sub _match_or_die {
    my($func,$value,$match) = @_;

    if (!defined $func || !defined $value || !defined $match || scalar @_ != 3) {
	die "BUG: got wrong arguments in _match_or_die. ".Dumper(@_);
    }
    
    if (ref \$match eq 'SCALAR') {	
	return $value eq $match;
    } elsif (ref $match eq 'Regexp') {
	return $value =~ $match;
    } else {
	die "$func: invalid argument, should be a scalar or a regexp.\n";
    }    
}

#----------------------------------------------------------------
#
#   from_pkg - check if the calling package matches the provided regular expression
#

sub from_pkg {
    return _match_or_die('from_pkg',get_caller_package,$_[0]);
}

#----------------------------------------------------------------
#
#   from_sub - check if the calling package matches the provided regular expression
#

sub from_sub {
    return _match_or_die('from_sub',get_caller_subname,$_[0]);
}

#----------------------------------------------------------------
#
#   is_sub - check that sub currently called matches the provided regular expression
#

sub is_sub {
    return _match_or_die('is_sub',get_subname,$_[0]);
}

1;

__END__

=head1 NAME

Hook::Filter::Plugin::Location - Functions for testing the location of a filtered subroutine

=head1 VERSION

$Id: Location.pm,v 1.1 2006/01/27 06:35:48 erwan Exp $

=head1 DESCRIPTION

Hook::Filter::Plugin::Location is a library of functions testing various
aspects of a subroutine's location. Those functions can be used inside
Hook::Filter rules, and only there.

=head1 SYNOPSIS

Exemples of rules using test functions from Hook::Filter::Plugin::Location:

    # allow all subroutine calls made from inside function 'do_this' from package 'main'
    from_sub('main::do_this')

    # allow all subroutine calls made from inside a function whose complete name matches /^Test::log.*/
    from_sub(qr{^Test::Log.*})

    # allow subroutine call if the called subroutine is 'MyModule::register'
    is_sub('MyModule::register')

    # allow subroutine call if the called subroutine matches /^My.*::register$/'
    is_sub(qr{^My.*::register$})

    # allow subroutine call if made from inside the module 'MyModule::Child'
    from_pkg('MyModule::Child')

    # allow subroutine call if made from inside a module whose name matches /^MyModule::Plugins::.*/
    from_pkg(qr{^MyModule::Plugins::.*})

=head1 INTERFACE - PLUGIN STRUCTURE

Like all plugin modules under Hook::Filter::Plugins, Hook::Filter::Plugins::Location
implements the class method C<< register() >>:

=over 4

=item B<register>()

Return the names of the test functions implemented in Hook::Filter::Plugins::Location. Used
by internally by Hook::Filter::Rule.

=back

=head1 INTERFACE - TEST FUNCTIONS

The following functions are only exported into Hook::Filter::Rule and 
shall only be used inside filter rules.
In the following, a complete subroutine name refers to the name
of that subroutine preceded by its package name and '::'.

=over 4

=item B<is_sub>(I<$scalar>)

Return true if the complete name of the currently filtered subroutine, for whom the rule 
containing C<< is_sub >> is being eval-ed, equals I<$scalar>. Return false otherwise.

=item B<is_sub>(I<$regexp>)

Return true if the complete name of the currently filtered subroutine, for whom the rule 
containing C<< is_sub >> is being eval-ed, matches I<$regexp>. Return false otherwise.

=item B<from_sub>(I<$scalar>)

Return true if the complete name of the subroutine that called the currently filtered
subroutine equals I<$scalar>. Return false otherwise.

=item B<from_sub>(I<$regexp>)

Return true if the complete name of the subroutine that called the currently filtered
subroutine matches I<$regexp>. Return false otherwise.

=item B<from_pkg>(I<$scalar>)

Return true if the name of the package from which the filtered subroutine was called
is I<$scalar>. Return false otherwise.

=item B<from_pkg>(I<$regexp>)

Return true if the name of the package from which the filtered subroutine was called
matches I<$regexp>. Return false otherwise.

=back

=head1 DIAGNOSTICS

No diagnostics. Any bug in those test functions would cause a warning emitted by Hook::Filter::Rule.

=head1 BUGS AND LIMITATIONS

See Hook::Filter

=head1 SEE ALSO

See Hook::Filter, Hook::Filter::Rule, Hook::Filter::Hook.

=head1 AUTHOR

Erwan Lemonnier C<< <erwan@cpan.org> >>.

=head1 COPYRIGHT AND LICENSE

See Hook::Filter.

=head1 DISCLAIMER OF WARRANTY

See Hook::Filter.

=cut



