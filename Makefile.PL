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
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'SDD-*' },
);
