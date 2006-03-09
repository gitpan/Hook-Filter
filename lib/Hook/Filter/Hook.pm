#################################################################
#
#   Hook::Filter::Hook - Wrap subroutines in a filtering closure
#
#   $Id: Hook.pm,v 1.1 2006/01/27 06:35:48 erwan Exp $
#
#   060302 erwan Created
#

package Hook::Filter::Hook;

use 5.006;
use strict;
use warnings;
use Carp qw(croak);
use Data::Dumper;
use Symbol;
use base qw(Exporter);

our @EXPORT = qw(get_caller_package
		 get_caller_file
		 get_caller_line
		 get_caller_subname
		 get_subname
		 get_arguments
		 );

our $VERSION = '0.01';

use vars qw($CALLER_PACKAGE $CALLER_FILE $CALLER_LINE $CALLER_SUBNAME $SUBNAME @ARGUMENTS);

#----------------------------------------------------------------
#
#
#   CLASS FUNCTIONS
#
#
#----------------------------------------------------------------

#----------------------------------------------------------------
#
#   accessors for use in Hook::Filter::Plugins:: modules
#

sub get_caller_package   { return $CALLER_PACKAGE; };
sub get_caller_file      { return $CALLER_FILE; };
sub get_caller_line      { return $CALLER_LINE; };
sub get_caller_subname   { return $CALLER_SUBNAME; };
sub get_subname          { return $SUBNAME; };
sub get_arguments        { return @ARGUMENTS; };

#----------------------------------------------------------------
#
#
#   OBJECT METHODS
#
#
#----------------------------------------------------------------

#----------------------------------------------------------------
#
#   new - build a new Hook::Filter::Hook
#

sub new {
    my($pkg) = @_;
    $pkg = ref $pkg || $pkg;
    my $self = bless({},$pkg);
    
    $self->{RULES} = [];
    $self->{SUBS} = {};
    
    return $self;
}

#----------------------------------------------------------------
#
#   register_rule - register a new Hook::Filter::Rule into self
#

sub register_rule {
    my($self,$rule) = @_;
    
    if (!defined $rule || ref $rule ne "Hook::Filter::Rule" || scalar @_ != 2) {
	shift @_;
	croak "invalid parameter: Hook::Filter::Hook->register_rule expects one instance of Hook::Filter::Rule, and not [".Dumper(@_)."]";
    }
    
    # TODO: silently skip registering the same rule twice?
    push @{$self->{RULES}}, $rule;
    
    return $self;
}

#----------------------------------------------------------------
#
#   flush_rules - erase all known rules
#

sub flush_rules {
    my($self) = @_;

    $self->{RULES} = [];

    return $self;
}

#----------------------------------------------------------------
#
#   filter_sub - build a filter closure wrapping calls to the provided sub
#

sub filter_sub {
    my($self,$subname) = @_;
    
    if (!defined $subname || ref \$subname ne "SCALAR" || scalar @_ != 2) {
	shift @_;
	croak "invalid parameter: Hook::Filter::Hook->filter_sub expects a subroutine name, but got [".Dumper(@_)."].";
    }

    if ($subname !~ /^(.+)::([^:]+)$/) {
	croak "invalid parameter: [$subname] is not a valid subroutine name (must include package name).";
    }

    my($pkg,$func) = ($1,$2);

    # check whether subroutine is already filtered, and skip if so
    if (exists $self->{SUBS}->{$subname}) {
	return $self;
    }
    
    my $filtered_func = *{ qualify_to_ref($func,$pkg) }{CODE};

    # create the closure that will replace $func in package $pkg
    my $filter = sub {
	my(@args) = @_;
	
	# TODO: looking at source for Hook::WrapSub, it might be a good idea to copy/paste some of its code here, to build a valid caller stack
	# TODO: look at Hook::LexWrap and fix so that caller() work in subroutines
	
	# set global variables
	$CALLER_PACKAGE  = (caller(0))[0];
	$CALLER_FILE     = (caller(0))[1];
	$CALLER_LINE     = (caller(0))[2];
	$CALLER_SUBNAME  = (caller(1))[3] || "";
	$SUBNAME         = $subname;
	@ARGUMENTS       = @args;

	# evaluate all rules, until all one is found to be true or all are found to be false
	foreach my $rule (@{$self->{RULES}}) {
	    if ($rule->eval()) {
		# found one rule that is true -> call subroutine in right context
		if (wantarray) {
		    my @results = $filtered_func->(@args);
		    return @results;
		} else {
		    my $result = $filtered_func->(@args);
		    return $result;
		}
	    }
	}

	# all rules evaluated to false, so skip subroutine, and fake a return value (bleh.)
	if (wantarray) {
	    return ();
	}
	return;
    };

    # keep track of already hooked subroutines
    $self->{SUBS}->{$subname} = 1;
    
    # replace $package::$func with our closure
    no strict 'refs';    
    no warnings;

    *{ qualify_to_ref($func,$pkg) } = $filter;

    return $self;
}

1;

__END__

=head1 NAME

Hook::Filter::Hook - Wrap subroutines in a filtering closure

=head1 VERSION

$Id: Hook.pm,v 1.1 2006/01/27 06:35:48 erwan Exp $

=head1 DESCRIPTION

=head1 SYNOPSIS

    use Hook::Filter::Hook;
    use Hook::Filter::Rule;

    my $hook = new Hook::Filter::Hook();

    my $rule = new Hook::Filter::Rule("in_package('My::Package') && in_sub('my_sub')");
    $hook->register_rule($rule);

    $hook->filter_sub("My::Package","mylog");

Later on, you may want to change the rules during runtime:

    $hook->flush_rules();
    $hook->register_rule($newrule1);
    $hook->register_rule($newrule2);

=head1 INTERFACE - METHODS

=over 4

=item B<new>()

Return a new generic Hook::Filter::Hook instance.

=item B<register_rule>(I<$rule>)

Add a new Hook::Filter::Rule I<$rule> to this Hook::Filter::Hook instance.

=item B<filter_sub>(I<$subname>)

Filter the function or method I<$subname>. I<$subname> must be of the form
C<< package_name::function_name >>.
All calls to C<< $subname >> will thereafter be redirected
to a wrapper closure that will evaluate all the rules registered in
Hook::Filter::Hook and if one of the rules evals to true,
the original function C<< $package::$sub() >> will be called normally.
Otherwise it will be skipped and its result simulated.

=item B<flush_rules>()

Remove all rules currently registered in this Hook::Filter::Hook.

=back

=head1 INTERFACE - CLASS FUNCTIONS

The following class functions are to be used by modules under
Hook::Filter::Plugins that implement specific test functions
for use in filter rules. 

Any use of the following functions in a different context than
inside the implementation of a filter rule test is guaranteed
to return only garbage. 

See Hook::Filter::Plugins::Location for a usage example.

=over 4

=item B<get_caller_package()> 

Return the name of the package calling the filtered subroutine.

=item B<get_caller_file()>

Return the name of the file calling the filtered subroutine.

=item B<get_caller_line()> 

Return the line number at which the filtered subroutine was called.

=item B<get_caller_subname()> 

Return the complete name (package+name) of the subroutine calling the filtered subroutine. 
If the subroutine was called directly from the main namespace, return an empty string.

=item B<get_subname()> 

Return the complete name of the filtered subroutine for which the rules
are being eval-ed.

=item B<get_arguments()>

Return the list of arguments that would be passed to the filtered subroutine.

=back

=head1 DIAGNOSTICS

=over 4

=item C<< $hook->register_rule($rule) >> croaks if I<$rule> is not a Hook::Filter::Rule.

=item C<< $hook->filter_sub(I<$pkg>,I<$func>) >> croaks when passed invalid arguments.

=item The closure wrapping all filtered subroutines emits perl warning when rules die upon being eval-ed.

=back

=head1 BUGS AND LIMITATIONS

See Hook::Filter

=head1 SEE ALSO

See Hook::Filter, Hook::Filter::Rule.

=head1 AUTHOR

Erwan Lemonnier C<< <erwan@cpan.org> >>.

=head1 COPYRIGHT AND LICENSE

See Hook::Filter.

=head1 DISCLAIMER OF WARRANTY

See Hook::Filter.

=cut



