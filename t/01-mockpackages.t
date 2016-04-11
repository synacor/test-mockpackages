#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

use Test::Tester;
use Test::Exception;
use Test::More;
use Test::MockPackages();

use FindBin qw($RealBin);
use lib "$RealBin/lib";
use TMPTestPackage();

isa_ok( my $mp = Test::MockPackages->new, 'Test::MockPackages' );

throws_ok(
    sub {
        $mp->pkg();
    },
    qr/^\$\Qpkg_name is required and must be a SCALAR/x,
    'requires pkg_name'
);

throws_ok(
    sub {
        $mp->pkg( [] );
    },
    qr/^\$\Qpkg_name is required and must be a SCALAR/x,
    'requires pkg_name to be a SCALAR'
);

my $m = $mp->pkg( 'TMPTestPackage' );
is( $m, $mp->pkg( 'TMPTestPackage' ), 'same object returned' );
isnt( $m, Test::MockPackages->new->pkg( 'TMPTestPackage' ), 'different objects returned' );

subtest 'generic test' => sub {
    check_tests(
        sub {
            my $m = Test::MockPackages->new();
            $m->pkg( 'TMPTestPackage' )->mock( 'subroutine' )->expects( 1, 2 )->returns( 'ok' );

            $m->pkg( 'TMPTestPackage' )->mock( 'method' )->never_called();

            $m->pkg( 'Other' )->mock( 'other_sub' )->expects( 2 )->called( 2 );

            TMPTestPackage::subroutine( 1, 2 );
            Other::other_sub( 2 );
            Other::other_sub( 2 );
        },
        [   {   ok    => 1,
                name  => 'TMPTestPackage::subroutine expects is correct',
                depth => -4,
            },
            {   ok    => 1,
                name  => 'Other::other_sub expects is correct',
                depth => -4,
            },
            {   ok    => 1,
                name  => 'Other::other_sub expects is correct',
                depth => -4,
            },
            {   ok    => 1,
                name  => 'Other::other_sub called 2 times',
                depth => -4,
            },
            {   ok    => 1,
                name  => 'TMPTestPackage::subroutine called 1 time',
                depth => -4,
            },
            {   ok    => 1,
                name  => 'TMPTestPackage::method called 0 times',
                depth => -4,
            },
        ]
    );
};

done_testing();
