#################################################################
#
#   Hook::Filter - A runtime filtering layer on top of subroutine calls
#
#   $Id: Filter.pm,v 1.7 2007/05/23 08:16:35 erwan_lemonnier Exp $
#
#   051105 erwan Created
#   060301 erwan Recreated
#   070516 erwan Updated POD and license, added flush_rules and add_rule
#   070522 erwan More POD + don't use rule file unless 'rules' specified in import
#   070523 erwan Can use 'rules' multiple time if same rule file specified
#   070523 erwan POD updates
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

our $VERSION = '0.06';

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

	croak "import parameter 'rules' for Hook::Filter should be a string, but was undef."
	    if (!defined $args{rules});

	croak "import parameter 'rules' for Hook::Filter should be a string, but was [".Dumper($args{rules})."]."
	    if (ref \$args{rules} ne 'SCALAR');

	croak "you tried to specify 2 different Hook::Filter rule file: [$RULES_FILE] and [".$args{rules}."]. you may have only 1 rule file."
	    if (defined $RULES_FILE && $RULES_FILE ne $args{rules});

	$RULES_FILE = $args{rules};
	delete $args{rules};
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

Hook::Filter - A runtime firewall for subroutine calls

=head1 DESCRIPTION

Hook::Filter is a runtime firewall for subroutine calls.

Hook::Filter lets you wrap one or more subroutines with a filter that
either forwards calls to the subroutine or blocks them, depending on
a number of rules that you define yourself. Each rule is simply one
line of Perl code that must evaluate to false (block the call) or true
(allow it).

The filtering rules are fetched from a file, called the rules file, or
they can be injected dynamically at runtime.

Each time a call is made to one of the filtered subroutines, all the
filtering rules are eval-ed, and if one of them returns true, the
call is forwarded, otherwise it is blocked. If no rules are defined,
all calls are forwarded by default.

Filtering rules are very flexible. You can block or allow calls to
a subroutine based on things such as the caller's identity, the
values of the arguments passed to the subroutine, the structure
of the call stack, or basically any other test that can be implemented
in Perl.

=head1 SYNOPSIS

To filter calls to the local subroutines C<mydebug>, C<myinfo> and
to C<Some::Other::Module::mywarn>:

    use Hook::Filter hook => [ "mydebug" ,"myinfo", "Some::Other::Module::mywarn" ];

To filter calls to the local subroutine C<_debug>, and import filtering
rules from the file C<~/debug.rules>:

    use Hook::Filter hook => '_debug', rules => '~/debug.rules';

The rule file C<~/debug.rules> could contain the following rules:

    # allow calls to 'mydebug' from within module 'My::Filthy:Attempt'
    subname eq 'mydebug' && from =~ /^My::Filthy::Attempt/

    # allow calls only from within a specific subroutine
    from eq 'My::Filthy::Attempt::func'

    # allow calls only if the subroutine's 2nd argument matches /bob/
    args(1) =~ /bob/

    # all other calls to 'myinfo', 'mydebug' or 'mywarn' will be skipped

You could also inject those rules dynamically at runtime:

    use Hook::Filter::RulePool qw(get_rule_pool);

    get_rule_pool->add_rule("subname eq 'mydebug' && from =~ /^My::Filthy::Attempt/");
                 ->add_rule("from =~ /^My::Filthy::Attempt::func$/");
                 ->add_rule("args(1) =~ /bob/");

To see which test functions can be used in rules, see Hook::Filter::Plugins::Library.

=head1 RULES

=head2 SYNTAX

A rule is a string containing one line of valid perl code that returns
either true or false when eval-ed. This line of code is usually made of
boolean operators combining functions that are exported by the modules
located under C<Hook::Filter::Plugins::>. See those modules for more details.

If you specify a rule file with the import parameter C<rules>, the rules
will be parsed out of this file according to the following syntax:

=over 4

=item * any line starting with C<< # >> is a comment.

=item * any empty line is ignored.

=item * any other line is considered to be a rule, ie a valid line of perl code that can be eval-ed.

=back

Each time one of the filtered subroutines is called, all loaded rules
are eval-ed until one returns true or all returned false. If one returns
true, the call is forwarded to the filtered subroutine, otherwise it is
skipped and a return value spoofed: either undef or an empty list,
depending on the context.

If a rule dies/croaks/confess upon being eval-ed (f.ex. when you left
a syntax error in the rule's string), it will be assumed
to have returned true. This is a form of fail-safe policy. You will
also get a warning message with a complete diagnostic.

=head2 RULE POOL

All rules are stored in a rule pool. You can use this pool to access
and manipulate rules during runtime.

There are 2 mechanisms to load rules into the pool:

=over 4

=item * Rules can be imported from a file at INIT time. Just specify the path
and name of this file with the import parameter C<< rules >>, and fill
this file with rules as shown in SYNOPSIS.

=item * Rules can also be injected dynamically at runtime. The following code
injects a rule that is always true, hence always allowing calls to the
filtered subroutines:

    use Hook::Filter::RulePool qw(get_rule_pool);
    get_rule_pool->add_rule("1");

=back

Rules can all be flushed at runtime:

    get_rule_pool->flush_rules();

For other operations on rules, see the modules C<Hook::Filter::RulePool>
and C<Hook::Filter::Rule>.

=head2 PASS ALL CALLS BY DEFAULT

If no rules are registered in the rule pool, or if all registered rules
die/croak when eval-ed, the default behaviour is to allow all calls to
the filtered subroutines.

That would happen for example if you specify no rule file via the import
parameter C<rules> and register no rules dynamically afterward.

To change this default behaviour, just add one default rule
that always returns false:

    use Hook::Filter::RulePool qw(get_rule_pool);
    get_rule_pool->add_rule("0");

All calls to the filtered subroutines are then blocked by default, as
long as no rule evals to true.

=head2 EXTENDING THE PLUGIN LIBRARY

The default plugin C<Hook::Filter::Plugins::Library> offers a number of
functions that can be used inside the filter rules, but you may want
to extend this library with your own functions.

You can easily do that by writing a new plugin module having the same
structure as C<Hook::Filter::Plugins::Library> and placing it under
C<Hook/Filter/Plugins/>. See C<Hook::Filter::Hooker> and
C<Hook::Filter::Plugins::Library> for details on how to do that.

=head1 INTERFACE

C<Hook::Filter> exports no functions.

C<Hook::Filter> accepts the following import parameters:

=over 4

=item C<< rules => $rules_file >>

Specify the complete path to a rule file. This import parameter can be used
only once in a program (usually in package C<< main >>) independently of how many
times C<< Hook::Filter >> is used. The file is parsed at INIT time.

See the RULES section for details.

Example:

    # look for rules in the local file 'my_rules'
    use Hook::Filter rules => 'my_rules';

=item C<< hook => $subname1 >> or C<< hook => [$subname1,$subname2...] >>

Specify which subroutines to filter. C<$subname> can either be a fully
qualified name or just the name of a subroutine located in the current
package.

If you C<use Hook::Filter> inside a package without specifying the import
parameter C<< hook >>, the same subroutines as specified in package C<< main >>
will be assumed by default.

Examples:

    # filter function debug() in the current package
    use Hook::Filter hook => 'debug';

    # filter function debug() in an other package
    use Hook::Filter hook=> 'Other::Package::debug';

    # do both at once
    use Hook::Filter hook=> [ 'Other::Package::debug', 'debug' ];

=back

=head1 DIAGNOSTICS

=over 4

=item Passing wrong arguments to C<Hook::Filter>'s import parameters will
cause it to croak.

=item The import parameter C<< hook >> must be used at least once otherwise
C<Hook::Filter> croaks with an error message.

=item An IO error when opening the rule file causes Hook::Filter to die.

=item An error in a filter rule will be reported with a perl warning.

=back

=head1 RESTRICTIONS

=head2 SECURITY

C<Hook::Filter> gives anybody with write permissions toward the rule file
the possibility to inject code into your application. This can be highly
dangerous! Protect your filesystem.

=head2 CAVEATS

=over 4

=item * Return values: when a call to a subroutine is allowed, the input and output arguments
of the subroutine are forwarded without modification. But when the call
is blocked, the subroutine's return value is simulated and will be C<< undef >>
in SCALAR context and an empty list in ARRAY context. Therefore, DO NOT filter
subroutines whose return values are significant for the rest of your code.

=item * Speed: Hook::Filter evaluates all filter rules for each call to a
filtered subroutine, which is slow. It would therefore be very unappropriate
to filter a heavily used subroutine in speed requiring applications.

=back

=head2 THREADS

Hook::Filter is not thread safe.

=head2 KEEP IT SIMPLE

The concept of blocking/allowing subroutine calls dynamically is somewhat
unusual and fun. Don't let yourself get too excited though. Doing that kind of
dynamic stuff makes your code harder to understand for non-dynamic developers,
hence reducing code stability.

=head1 USE CASE

Why would one need a firewall for subroutine calls?
Here are a couple of relevant use cases:

=over 4

=item * A large application logs a lot of information. You want to implement
a logging policy to limit the amount of logged information, but you don't want
to modify the logging code. You do that by filtering the functions defined in
the logging API with C<Hook::Filter>, and by defining a rule file that implements
your logging policy.

=item * A large application crashes regularly so you decide to turn on debugging
messages system wide with full verbosity. You get megazillions of log messages.
Instead of greping your way through them or starting your debugger, you use C<Hook::Filter>
to filter the function that logs debug messages and define tailored rules that
allow only relevant debug messages to be logged.

=back

=head1 SEE ALSO

See Hook::Filter::Rule, Hook::Filter::RulePool, Hook::Filter::Plugins::Library, Hook::Filter::Hooker.
See even Hook::WrapSub, Log::Localized, Log::Log4perl, Log::Dispatch.

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-hook-filter@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 REPOSITORY

The source of Hook::Filter is hosted at sourceforge. You can access
it at https://sourceforge.net/projects/hook-filter/.

=head1 AUTHOR

Written by Erwan Lemonnier C<< <erwan@cpan.org> >> based on inspiration
received during the 2005 Nordic Perl Workshop. Kind thanks to Claes Jakobsson &
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






