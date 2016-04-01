use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Test::MockPackages',
    AUTHOR              => q{Tom Peters <tpeters@synacor.com>},
    VERSION_FROM        => 'lib/Test/MockPackages.pm',
    ABSTRACT_FROM       => 'lib/Test/MockPackages.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Test-MockPackages-*' },
);
