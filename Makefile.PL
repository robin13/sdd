use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'SDD',
    AUTHOR              => q{Robin Clarke <perl@robinclarke.net>},
    VERSION_FROM        => 'lib/SDD.pm',
    ABSTRACT_FROM       => 'lib/SDD.pm',
    EXE_FILES           => [ 'bin/sdd' ],
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
	'File::Basename'   => 0,
	'Getopt::Long'     => 0,
	'IPC::Run'         => 0,
	'Log::Log4perl'    => 0,
	'Params::Validate' => 0,
	'Pod::Usage'       => 0,
        'Test::More'       => 0,
	'YAML::Any'        => 0,
	'User'             => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'SDD-*' },
);
