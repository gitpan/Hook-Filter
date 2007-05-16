#################################################################
#
#   Hook::Filter - A runtime filtering layer on top of subroutine calls
#
#   $Id: Filter.pm,v 1.3 2007/05/16 14:36:51 erwan_lemonnier Exp $
#
#   051105 erwan Created
#   060301 erwan Recreated
#   070516 erwan Updated POD and license, added flush_rules and add_rule
#

package Hook::Filter;

use 5.006;
use strict;
use warnings;
use Carp qw(confess croak);
use File::Spec;
use Hook::Filter::Rule;
use Hook::Filter::RulePool qw(get_rule_pool);
use Hook::Filter::Hooker qw(filter_sub);
use base qw(Exporter);
use Data::Dumper;

our @EXPORT = qw();

our $VERSION = '0.03';

#----------------------------------------------------------------
#
#   Global vars
#
#----------------------------------------------------------------

# the rule file actually used by Hook::Filter, and as declared with parameter 'rules'
my $RULES_FILE;

# hooked functions per namespace
my %HOOKED_SUBS;

#----------------------------------------------------------------
#
#   import - verify and save import parameters
#

sub import {
    my($class,%args) = @_;
    my $pkg = caller(0);

    # check parameter 'rules', indicating path to the rules file
    if (exists $args{rules}) {
	if (defined $RULES_FILE) {
	    croak "Invalid parameter: 'rules' for Hook::Filter cannot be used more than once.";
	}
	if (!defined $args{rules}) {
	    croak "Invalid parameter: 'rules' for Hook::Filter should be a string, but was undef.";
	} elsif (ref \$args{rules} eq 'SCALAR') {
	    $RULES_FILE = $args{rules};
	} else {
	    croak "Invalid parameter: 'rules' for Hook::Filter should be a string, but was [".Dumper($args{rules_path})."].";
	}
	delete $args{rules_path};
    }

    # check parameter 'hook', indicating which subroutines to filter in this package
    if (exists $args{hook}) {
	if (!defined $args{hook}) {
	    croak "Invalid parameter: 'hook' should be a string or an array of strings, but was undef.";
	} elsif (ref $args{hook} eq 'ARRAY') {
	    foreach my $name (@{$args{hook}}) {
		if (ref \$name ne 'SCALAR') {
		    croak "Invalid parameter: 'hook' for Hook::Filter should be a string or an array of strings, but was [".Dumper($args{hook})."].";
		}
	    }
	    $HOOKED_SUBS{$pkg} = $args{hook};
	} elsif (ref \$args{hook} eq 'SCALAR') {
	    $HOOKED_SUBS{$pkg} = [ $args{hook} ];
	} else {
	    croak "Invalid parameter: 'hook' for Hook::Filter should be a string or an array of strings, but was [".Dumper($args{hook})."].";
	}
	delete $args{hook};
    } else {
	# if no hooked subroutine specified, use the one declared in main
	if ($pkg eq 'main') {
	    croak "Invalid parameter: 'use Hook::Filter' must be followed by parameter 'hook' in at least the main module.";
	}

	$HOOKED_SUBS{$pkg} = "main";
    }

    # propagate super class's import
    $class->export_to_level(1,undef,());
}

sub _test_import_flush {
    $RULES_FILE = undef;
}

#################################################################
#
#
#   INIT BLOCK
#
#
#################################################################

# This block executes after import and before running actual program
INIT {

    # initiate a rule pool and a hooker
    my $pool = get_rule_pool();

    #----------------------------------------------------------------
    #
    #   find rules file
    #

    if (!$RULES_FILE) {
	# find rules file
	foreach my $path ('~/.hook_filter','.') {
	    my $file = File::Spec->catfile($path,"hook_filter.rules");
	    if (-f $file) {
		$RULES_FILE = $file;
		last;
	    }
	}
    }

    #----------------------------------------------------------------
    #
    #   load rules from rules file, if any
    #

    if (defined $RULES_FILE && -f $RULES_FILE) {

	# TODO: support runtime monitoring of rules file and update of rules upon changes in file

	open(IN,"$RULES_FILE")
	    or confess "failed to open Hook::Filter rules file [$RULES_FILE]: $!";
	while (my $line = <IN>) {
	    chomp $line;
	    next if ($line =~ /^\s*\#/);
	    next if ($line =~ /^\s*$/);

	    my $rule = new Hook::Filter::Rule($line);
	    $rule->source($RULES_FILE);
	    $pool->add_rule($rule);
	}
	close(IN);
    }

    #----------------------------------------------------------------
    #
    #   wrap all filtered methods with the firewalling hook
    #

    foreach my $pkg (keys %HOOKED_SUBS) {
	# if a module uses Hook::Filter without specifying 'hook => ...', the list of hooked
	# functions should be the same as in the main declaration
	if (ref \$HOOKED_SUBS{$pkg} eq 'SCALAR') {
	    if ($HOOKED_SUBS{$pkg} ne 'main') {
		die "BUG: the only scalar value allowed in HOOK_SUBS is 'main', not [".$HOOKED_SUBS{$pkg}."].";
	    }
	    $HOOKED_SUBS{$pkg} = $HOOKED_SUBS{'main'};
	}

	foreach my $method (@{$HOOKED_SUBS{$pkg}}) {
	    # if method is already a complete path, use it, hence modifying a method in an other module
	    if ($method =~ /::/) {
		filter_sub($method);
	    } else {
		filter_sub($pkg."::".$method);
	    }
	}
    }
}

1;

__END__

=head1 NAME

Hook::Filter - A runtime filtering layer on top of subroutine calls

=head1 DESCRIPTION

Hook::Filter is a runtime firewall for subroutine calls.

Hook::Filter lets you wrap one or more subroutines with a filter that
either forwards calls to the subroutine or blocks them, depending on
a number of rules that you define yourself. Those rules are simply
Perl one-liners that must evaluate to false (block the call) or true
(allow it).

The filtering rules are stored in a file, called the rules file.

Each time a call is made to one of the filtered subroutines, all the
filtering rules are eval-ed, and if one of them returns true, the
call is forwarded, otherwise it is blocked. If no rules file exists,
or if a rule dies or contains syntax errors, all calls are forwarded
by default.

Filtering rules are very flexible. You can block or allow calls to
a subroutine based on things such as the caller's identity, the
values of the arguments passed to the subroutine, the structure
of the call stack,
or basically any other test that can be implemented in Perl.

=head1 SYNOPSIS

To hook a number of subroutines:

    # filter the subs mydebug() and myinfo() located in the current
    # module, as well as sub mywarn() located in Some::Other::Module
    use Hook::Filter hook => ["mydebug","myinfo","Some::Other::Module::mywarn"];

Then create a rules file. By default it is a file called I<./hook_filter.rules>,
and could look like:


    # allow calls to 'mydebug' only inside package 'My::Filthy:Attempt'
    subname eq 'mydebug' && from =~ /^My::Filthy::Attempt/

    # allow calls only if the caller's fully qualified name matches a pattern
    from =~ /^My::Filthy::Attempt::func$/

    # allow calls only if the subroutine's 2nd argument matches /bob/
    args(1) =~ /bob/

    # all other calls to 'myinfo', 'mydebug' or 'mywarn' will be skipped

To see which test functions can be used in rules, see Hook::Filter::Plugins::Library.

=head2 RULES

A rule is one line of valid perl code that returns either true or false
when eval-ed. This line of code is usually made of boolean operators
combining functions that are exported by the modules located under
Hook::Filter::Plugins::. See those modules for more details.

Rules are loaded from a file. By default this file is called
C<< hook_filter.rules >> and must be located either in the running
program current directory or in the user's home directory.

You can change the default name and location of the rules file
with the import parameter C<< rules >>.

If no rules file is found, all subroutine calls will be allowed
by default.

Rules are parsed from the rules file only once, when the module inits.

The rules file has a straightforward syntax:

=over 4

=item * any line starting with C<< # >> is a comment

=item * any empty line is skipped

=item * any other line is considered to be a rule, ie a valid line of perl code

=back

Each time one of the filtered subroutines is called, all loaded rules
are eval-ed until one returns true or all returned false. If one returns
true, the call is forwarded to filtered subroutine, otherwise it is
skipped and a return value spoofed: either undef or an empty list,
depending on the context.

If a rule dies/croaks/confess upon being eval-ed (f.ex. when you left
a syntax error in your rules file), it will be assumed
to have returned true. This is a form of fail-safe policy. A warning
message with a complete diagnostic will be emitted with C<< warn >>.

=head2 EXTENDING THE PLUGIN LIBRARY

The default plugin Hook::Filter::Plugins::Library offers a number of
functions that can be used inside the filter rules, but you may want
extend those functions with your own ones.

You can easily do that by writing a new plugin module having the same
structure as Hook::Filter::Plugins::Library and placing it under
Hook/Filter/Plugins/. See Hook::Filter::Hooker and Hook::Filter::Plugins::Library
for details on how to do that.

=head2 CAVEATS

=over 4

=item * Return values: when a call to a subroutine is allowed, the input and output arguments
of the subroutine are forwarded without modification. But when the call
is blocked, the subroutine response is simulated and will be C<< undef >>
in SCALAR context and an empty list in ARRAY context. Therefore, DO NOT filter
subroutines whose return values are significant for the rest of your code.

=item * Execution time: Hook::Filter evaluates all filter rules for each call to a
filtered subroutine. It would therefore be very unappropriate to
filter a heavily used subroutine in speed requiring applications.

=back

=head2 USE CASE

Why would one need a runtime function call firewall??
Here are a couple of relevant use cases:

=over 4

=item * A large application logs a lot of information. You want to implement
a logging policy to limit the amount of logged information, but you don't want
to modify the logging code. You do that by filtering the functions defined in
the logging API with Hook::Filter, and by defining a rules file that implements
your logging policy.

=item * A large application crashes regularly so you decide to turn on debugging
messages system wide with full verbosity. You get gazillions of log messages.
Instead of greping your way through them or starting your debugger, you use Hook::Filter
to filter the function that logs debug messages and define tailored rules that
allow only relevant debug messages to be logged.

=back

The concept of a blocking/allowing subroutine call dynamically is somewhat
mind bobbling. Don't let yourself get too excited though. Doing that kind of
dynamic stuff makes your code harder to understand for non-dynamic developers,
hence reducing code stability.

=head1 INTERFACE - API



=head1 INTERFACE - IMPORT PARAMETERS

Hook::Filter accepts the following import parameters:

=over 4

=item C<< rules => $rules_file >>

Specify the complete path to the rules file. This import parameter can be used
only once in a program (usually in package C<< main >>) independently of how many
times C<< Hook::Filter >> is used.

See the RULES section for details.

Example:

    # look for rules in the local file 'my_rules'
    use Hook::Filter rules => 'my_rules';

=item C<< hook => $subname1 >> or C<< hook => [$subname1,$subname2...] >>

Specify which subroutines should be filtered in the current module. C<$subname>
can either be a fully qualified name or just a subroutine name from a
subroutine located in the current package.

If you use Hook::Filter without specifying C<< hook >>, the same subroutines
as specified in package C<< main >> are assumed.

Example:

    # filter function debug in the current package
    use Hook::Filter hook => 'debug';

    # filter function debug in an other package
    use Hook::Filter hook=> 'Other::Package::debug';

    # do both at once
    use Hook::Filter hook=> [ 'Other::Package::debug', 'debug' ];

=back

=head1 DIAGNOSTICS

=over 4

=item Passing wrong arguments to Hook::Filter's import parameters will
cause it to croak.

=item The import parameter C<< hook >> must be used at least in package C<< main >>
otherwise Hook::Filter croaks with an error message.

=item An IO error when opening the rules file causes Hook::Filter to die.

=item An error in a filter rule will be reported with a perl warning.

=back

=head1 SECURITY

Hook::Filter gives anybody who has the rights to create or manipulate a rules file
the possibility to inject code into your running application at runtime. This
can be highly dangerous! Protect your filesystem.

=head1 THREADS

Hook::Filter is not thread safe.

=head1 SEE ALSO

See Hook::WrapSub, Log::Localized, Log::Log4perl, Log::Dispatch.

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-hook-filter@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 REPOSITORY

The source of Hook::Filter is hosted at sourceforge. You can access
it at https://sourceforge.net/projects/hook-filter/.

=head1 AUTHOR

Written by Erwan Lemonnier C<< <erwan@cpan.org> >> based on inspiration
received during the 2005 perl Nordic Workshops. Kind thanks to Claes Jacobsson &
Jerker Montelius for their suggestions and support!

=head1 LICENSE

This code was developed partly during free-time
and partly at the Swedish Premium Pension Authority as part of
the Authority's software development activities. This code is distributed
under the same terms as Perl itself. We encourage you to help us improving
this code by sending feedback and bug reports to the author(s).

This code comes with no warranty. The Swedish Premium Pension Authority and the author(s)
decline any responsibility regarding the possible use of this code or any consequence
of its use.

=cut






