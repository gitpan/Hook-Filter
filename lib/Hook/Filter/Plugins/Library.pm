#################################################################
#
#   Hook::Filter::Plugin::Library - Usefull functions for writing filter rules
#
#   $Id: Library.pm,v 1.1 2007/05/16 15:44:21 erwan_lemonnier Exp $
#
#   060302 erwan Created
#   070516 erwan Removed from_xxx(), added from(), arg() and subname()
#

package Hook::Filter::Plugins::Library;

use strict;
use warnings;
use Carp qw(croak);
use Data::Dumper;
use Hook::Filter::Hooker qw( get_caller_subname get_caller_package get_subname get_arguments );

#----------------------------------------------------------------
#
#   register - return a list of the tests available in this plugin
#

sub register {
    return qw(from arg subname);
}

#----------------------------------------------------------------
#
#   from - returns the fully qualified name of the caller
#

sub from {
    return get_caller_subname;
}

#----------------------------------------------------------------
#
#   arg - return the n-ieme argument passed to the filtered subroutine
#

sub arg {
    my $pos = shift;
    croak "invalid rule: function arg expects a number, got: ".Dumper($pos,@_) if (!defined $pos || @_ || $pos !~ /^\d+$/);
    my @args = get_arguments;
    return $args[$pos];
}

#----------------------------------------------------------------
#
#   subname - return the fully qualified name of the called subroutine
#

sub subname {
    return get_subname;
}

1;

__END__

=head1 NAME

Hook::Filter::Plugin::Library - Usefull functions for writing filter rules

=head1 DESCRIPTION

A library of functions usefull when writing filter rules.
Those functions should be used inside Hook::Filter rules, and only there.

=head1 SYNOPSIS

Exemples of rules using test functions from Hook::Filter::Plugin::Location:

    # allow all subroutine calls made from inside function 'do_this' from package 'main'
    from =~ /main::do:this/

    # the opposite
    from !~ /main::do:this/

    # the called subroutine matches a given name
    subname =~ /foobar/

    # the 2nd argument of passed to the subroutine is a string matching 'bob'
    defined arg(1) && arg(1) =~ /bob/

=head1 INTERFACE - TEST FUNCTIONS

The following functions are only exported into Hook::Filter::Rule and
shall only be used inside filter rules.

=over 4

=item B<from>

Return the fully qualified name of the caller of the filtered subroutine.

=item B<subname>

Return the fully qualified name of the filtered subroutine being called.

=item B<arg>($pos)

Return the argument at position C<$pos> in the list of arguments to be
passed to the filtered subroutine.

Example:

    use Hook::Filter hook => 'debug';

    debug(1,"some message");

    # in a rule file:
    # the rule 'arg(0) <= 2' would evaluate to '1 <= 2' and be true
    # the rule 'arg(1) =~ /some/' would evaluate to '"some message" =~ /some/' and be true

=back

=head1 INTERFACE - PLUGIN STRUCTURE

Like all plugins under Hook::Filter::Plugins, Hook::Filter::Plugins::Library implements the class method C<< register() >>:

=over 4

=item B<register>()

Return the names of the test functions implemented in Hook::Filter::Plugins::Location. Used
by internally by Hook::Filter::Rule.

=back

=head1 DIAGNOSTICS

No diagnostics. Any bug in those test functions would cause a warning emitted by Hook::Filter::Rule.

=head1 BUGS AND LIMITATIONS

See Hook::Filter

=head1 SEE ALSO

See Hook::Filter, Hook::Filter::Rule, Hook::Filter::Hooker.

=head1 VERSION

$Id: Library.pm,v 1.1 2007/05/16 15:44:21 erwan_lemonnier Exp $

=head1 AUTHOR

Erwan Lemonnier C<< <erwan@cpan.org> >>.

=head1 LICENSE

See Hook::Filter.

=cut



