#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

use Test::Exception;
use Test::More;
use Test::MockPackages();

use FindBin qw($RealBin);
use lib "$RealBin/lib";
use TMPTestPackage();

isa_ok( my $mp = Test::MockPackages->new, 'Test::MockPackages' );

throws_ok( sub {
    $mp->package()
}, qr/^\$\Qpackage_name is required/x, 'requires package_name' );

do {
    my $obj = TMPTestPackage->new;
    is( $obj->method("one", "two"), "method return: one, two", 'original method called' );
    is( TMPTestPackage::subroutine("one", "two"), "subroutine return: one, two", 'original subroutine called' );

    isa_ok( my $p = $mp->package('TMPTestPackage'), 'Test::MockPackages::Package' );

    $p->mock('method');
        ->method
        ->expects('one', 'two')
        ->expects('three', 'four')
        ->returns('OK')
        ->returns('OK2');
};

done_testing();
