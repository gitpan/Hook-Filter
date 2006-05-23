use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Hook::Filter',
    VERSION_FROM      => 'lib/Hook/Filter.pm', # finds $VERSION
    PREREQ_PM         => {
	Module::Pluggable => 2.2,
	File::Spec => 0.86,
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Hook/Filter.pm', # retrieve abstract from module
       AUTHOR         => 'Erwan Lemonnier <erwan@cpan.org>') : ()),
);
