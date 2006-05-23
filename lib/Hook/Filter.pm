#################################################################
#
#   Hook::Filter - A runtime filtering layer on top of subroutine calls
#
#   $Id: Filter.pm,v 1.2 2006/05/23 07:12:48 erwan Exp $
#
#   051105 erwan Created
#   060301 erwan Recreated
#

package Hook::Filter;

use 5.006;
use strict;
use warnings;
use Carp qw(confess croak);
use File::Spec;
use Hook::Filter::Hook;
use Hook::Filter::Rule;
use base qw(Exporter);
use Data::Dumper;

our @EXPORT = qw();

our $VERSION = '0.02';

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

    # if no rules file found, skip the rest
    return if (!defined $RULES_FILE || !-f $RULES_FILE);

    #----------------------------------------------------------------    
    #
    #   load rules
    #

    my $hook = Hook::Filter::Hook->new();

    # TODO: support runtime monitoring of rules file and update of rules upon changes in file

    open(IN,"$RULES_FILE")
	or confess "failed to open Hook::Filter rules file [$RULES_FILE]: $!";
    while (my $line = <IN>) {
	chomp $line;
	next if ($line =~ /^\s*\#/);
	next if ($line =~ /^\s*$/);
	my $rule = Hook::Filter::Rule->new($line);
	$rule->source($RULES_FILE);
	$hook->register_rule($rule);
    }
    close(IN);
    
    foreach my $pkg (keys %HOOKED_SUBS) {
	# if a module 'use Hook::Filter' without specifying 'hook => ...', the list of hooked
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
		$hook->filter_sub($method);
	    } else {
		$hook->filter_sub($pkg."::".$method);
	    }
	}
    }
}

1;

__END__

=head1 NAME

Hook::Filter - A runtime filtering layer on top of subroutine calls

=head1 SYNOPSIS

Imagine you have a big program using a logging library that
exports 3 functions called I<mydebug>, I<myinfo> and I<mywarn>.
Those functions generate far too much log, so you want
to skip calling them except in some specific circumstances.

In your main program, write:

    use Hook::Filter hook => ["mydebug","myinfo","mywarn"];

In all modules making use of the logging library, write:

    use Hook::Filter;

Then create a file called I<./hook_filter.rules>. This file
contains boolean expressions that specify when calls
to the filtered subroutines should be allowed:

    # allow calls to 'mydebug' only inside package 'My::Filthy:Attempt'
    is_sub('mydebug') && from_pkg('My::Filthy::Attempt')

    # allow all calls to 'myinfo' except from inside packages under the namespace My::Test::
    is_sub('myinfo') && !from_pkg(/^My::Test/)

    # allow calls to 'mywarn' from function 'do_stuff' in package 'main' 
    # whose third argument is a message that does not match the string 'invalid login name' 
    is_sub('mywarn') && from_sub('do_stuff') && from_pkg('main') && !has_arg(3,/invalid login name/)

    # all other calls to 'myinfo', 'mydebug' or 'mywarn' will be skipped
    
=head1 SYNOPSIS, Log::Dispatch

Your program uses C<< Log::Dispatch >>. You want to enable Hook::Filter
on top of the methods C<< log >> and C<< log_to >> from C<< Log::Dispatch >> 
everywhere at once. And you want to use the filter rules located in 
C<< /etc/myconf/filter_rules.conf >>. 
Easy: in C<< main >>, write:

    use Hook::Filter rules => '/etc/myconf/filter_rules.conf', hook => ['Log::Dispatch::log','Log::Dispatch::log_to'];

That's all!

=head1 DESCRIPTION

Hook::Filter is a runtime firewall for subroutine calls.

Hook::Filter lets you hook some subroutines and define rules to specify
when calls to those subroutines should be allowed or skipped. Those rules
are very flexible and are eval-ed during runtime each time a call to one
of the hooked subroutine is made. 

=head2 RULES

A rule is one line of valid perl code that returns either true or false
when eval-ed. This line of code is usually made of boolean operators
combining functions that are exported by the modules located under
Hook::Filter::Plugins::. 

See Hook::Filter::Plugins::Location for details.

Rules are loaded from a file. See the import parameter C<< rules >>
for a description of how to specify the rules file.

Rules are parsed from the rules file only once, when the module inits.

This file follows a standard syntax: a line starting with C<< # >> is
a comment, any other line is considered to be a rule, ie a valid line
of perl code.

Each time one of the filtered subroutines is called, all loaded rules
are eval-ed until one returns true or all returned false. If one returns
true, the filtered subroutine is called transparantly, otherwise it is
skipped and its return value is set to either undef or an empty list,
depending on the context.

If a rule dies/croaks/confess upon being eval-ed (f.ex. when you left
a syntax error in your rules file), it will be assumed
to have returned true. This is a form of fail-safe policy. A warning
message with a complete diagnostic will be emitted with C<< warn >>.

=head2 CREATING NEW RULE TESTS

Filter rules are made of perl code mixed with test functions that are imported
from the modules located under C<< Hook::Filter::Plugins:: >>. Hook::Filter comes
with a number of default plugin modules that implement the default rule
tests (such as C<< from_sub >>, C<< is_sub >>, C<< has_arg >>, etc.). Those modules
are loaded into Hook::Filter using Module:Pluggable. It is therefore
quite easy to extend the existing set of test functions by writing your
own Hook::Filter plugins. See I<Hook::Filter::Plugins::Location> for an
exemple on how to do that.

=head2 CAVEATS

When a call to a subroutine is allowed, the input and output arguments
of the subroutine are forwarded without modification. But when the call
is blocked, the subroutine response is simulated and will be C<< undef >>
in SCALAR context and an empty list in ARRAY context. So do not filter
subroutines whose return values are significant for the rest of your code.

Time. Hook::Filter evaluates all filter rules for each call to a 
filtered subroutine. It would therefore be very unappropriate to
filter a heavily used subroutine.

=head2 USE CASE

Why the hell would one want to do such a creepy thing to his code? 

Well, the main use case if that of easily building a log policy on top of a 
logging library in a large application. You want a dynamic and flexible
way to define what should be logged and in which circumstances, without
having to actually edit the aplication's code. Just use Hook::Filter
like in the SYNOPSIS and define a system wide rules file.

Or you have a large application that is crashing and you decide to turn on 
debug verbosity system wide. You do so and get gazillions of log messages.
Instead of greping your way through them or starting your debugger, you use Hook::Filter at the relevant
places in your application and filter away all irrelevant debug messages with
a tailored set of rules that allow only the right information to be logged.

Your application is managed during runtime by an awe inspiring AI engine that 
continuously produces filter rules to dynamically alter the call flow
inside you application (don't ask why! this sounds like sick design anyway...).

The concept of a dynamic subroutine call filter being somewhat mind bobbling,
you will surely imagine some new twisted use cases (and let me know then!).

=head1 INTERFACE

Hook::Filter exports no functions. It only has the following import parameters:

=over 4

=item C<< rules => $rules_file >>

Specify the complete path to the rules file. This import parameter can be used
only once in a program (usually in package C<< main >>) independently of how many times C<< use Hook::Filter >> 
is written. If it is not specified anywhere, Hook::Filter will by default search
for a file named C<< hook_filter.rules >> located in C<< ./ >> or under 
C<< ~/.hook_filter/ >>.
If no file is found or if the rules file contains no valid rules, no subroutines
will be filtered.

=item C<< hook => $subname1 >> or C<< hook => [$subname1,$subname2...] >>

Specify which subroutines should be filtered in the current module. If 
Hook::Filter is used without specifying C<< hook >>, the same function
names as specified in package C<< main >> are taken.

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

=head1 AUTHOR

Written by Erwan Lemonnier C<< <erwan@cpan.org> >> based on inspiration
received during the 2005 perl Nordic Workshops. Kind thanks to Claes Jacobsson &
Jerker Montelius for their suggestions and support!

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Erwan Lemonnier C<< <erwan@cpan.org> >>

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

Because this software is licensed free of charge, there is no warranty
for the software, to the extent permitted by applicable law. Except when
otherwise stated in writing the copyright holders and/or other parties
provide the software "as is" without warranty of any kind, either
expressed or implied, including, but not limited to, the implied
warranties of merchantability and fitness for a particular purpose. The
entire risk as to the quality and performance of the software is with
you. Should the software prove defective, you assume the cost of all
necessary servicing, repair, or correction.

In no event unless required by applicable law or agreed to in writing
will any copyright holder, or any other party who may modify and/or
redistribute the software as permitted by the above licence, be
liable to you for damages, including any general, special, incidental,
or consequential damages arising out of the use or inability to use
the software (including but not limited to loss of data or data being
rendered inaccurate or losses sustained by you or third parties or a
failure of the software to operate with any other software), even if
such holder or other party has been advised of the possibility of
such damages.

=cut






