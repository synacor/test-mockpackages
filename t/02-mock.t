#!/usr/bin/env perl;
use strict;
use warnings;
use 5.012;

use Test::Exception;
use Test::More;
use Test::MockPackages::Mock();
use FindBin qw($RealBin);
use lib "$RealBin/lib";
use TMPTestPackage();

subtest 'missing sub' => sub {
    ok( !TMPTestPackage->can('missing'), 'cannot call missing' );

    my $m = Test::MockPackages::Mock->new('TMPTestPackage', 'missing');
    ok( TMPTestPackage->can('missing'), 'can call missing' );

    undef $m;
    ok( !TMPTestPackage->can('missing'), 'cannot call missing' );
};

subtest 'existing sub' => sub {
    ok( TMPTestPackage->can('subroutine'), 'can call subroutine' );
    is( TMPTestPackage::subroutine('a', 'b'), 'subroutine return: a, b', 'correct return' );

    my $m = Test::MockPackages::Mock->new('TMPTestPackage', 'subroutine');
    $m->returns('overwrote')
      ->expects('a', 'b');
    is( TMPTestPackage::subroutine('a', 'b'), 'overwrote', 'correct return' );

    undef $m;
    is( TMPTestPackage::subroutine('a', 'b'), 'subroutine return: a, b', 'correct return' );
};

subtest 'nested mocks' => sub {
    ok( !TMPTestPackage->can('missing'), 'cannot call missing' );

    my $m = Test::MockPackages::Mock->new('TMPTestPackage', 'missing');
    $m->called(2);
    $m->returns('OK');
    ok( TMPTestPackage->can('missing'), 'can call missing' );
    is( TMPTestPackage::missing(), 'OK', 'returns OK' );

    do {
        my $m2 = Test::MockPackages::Mock->new('TMPTestPackage', 'missing');
        $m2->returns('OK2');
        is( TMPTestPackage::missing(), 'OK2', 'returns OK2' );
    };

    is( TMPTestPackage::missing(), 'OK', 'missing() returns OK again' );

    undef $m;
    ok( !TMPTestPackage->can('missing'), 'cannot call missing' );
};

subtest 'never' => sub {
    subtest 'never called' => sub {
        my $m = Test::MockPackages::Mock->new('TMPTestPackage', 'subroutine');
    };
};

done_testing();
