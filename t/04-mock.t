#!/usr/bin/env perl
use strict;
use warnings;
use 5.012;

use Const::Fast qw(const);
use English qw(-no_match_vars);
use Lingua::EN::Inflect qw(NUMWORDS PL);
use Test::Tester;
use Test::Exception;
use Test::More;
use Test::MockPackages::Mock();
use Test::MockPackages::Returns qw(returns_code);
use FindBin qw($RealBin);
use lib "$RealBin/lib";
use TMPTestPackage();

const my $OK     => 1;
const my $NOT_OK => 0;

subtest 'overrides' => sub {
    subtest 'missing sub' => sub {
        ok( !TMPTestPackage->can( 'missing' ), 'cannot call missing' );

        my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'missing' );
        ok( TMPTestPackage->can( 'missing' ), 'can call missing' );

        undef $m;
        ok( !TMPTestPackage->can( 'missing' ), 'cannot call missing' );
    };

    subtest 'existing sub' => sub {
        ok( TMPTestPackage->can( 'subroutine' ), 'can call subroutine' );
        is( TMPTestPackage::subroutine( 'a', 'b' ), 'subroutine return: a, b', 'correct return' );

        my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' );
        $m->returns( 'overwrote' )->expects( 'a', 'b' );
        is( TMPTestPackage::subroutine( 'a', 'b' ), 'overwrote', 'correct return' );

        undef $m;
        is( TMPTestPackage::subroutine( 'a', 'b' ), 'subroutine return: a, b', 'correct return' );
    };

    subtest 'nested mocks' => sub {
        ok( !TMPTestPackage->can( 'missing' ), 'cannot call missing' );

        my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'missing' );
        $m->called( 2 );
        $m->returns( 'OK' );
        ok( TMPTestPackage->can( 'missing' ), 'can call missing' );
        is( TMPTestPackage::missing(), 'OK', 'returns OK' );

        do {
            my $m2 = Test::MockPackages::Mock->new( 'TMPTestPackage', 'missing' );
            $m2->returns( 'OK2' );
            is( TMPTestPackage::missing(), 'OK2', 'returns OK2' );
        };

        is( TMPTestPackage::missing(), 'OK', 'missing() returns OK again' );

        undef $m;
        ok( !TMPTestPackage->can( 'missing' ), 'cannot call missing' );
    };
};

subtest 'never' => sub {
    subtest 'never called' => sub {
        check_test(
            sub {
                my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' );
                $m->never_called();
            },
            {   ok    => 1,
                name  => "TMPTestPackage::subroutine called 0 times",
                depth => -4,
            },
            'never_called()'
        );
    };

    subtest 'never fails' => sub {
        check_test(
            sub {
                my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' );
                $m->never_called();

                TMPTestPackage::subroutine( "hi" );
            },
            {   ok    => 0,
                name  => "TMPTestPackage::subroutine called 0 times",
                depth => -4,
            },
            'never_called()'
        );
    };
};

subtest 'called' => sub {
    my $test = sub {
        my ( $ok, $called, $invoked ) = @ARG;

        check_test(
            sub {
                my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->called( $called );

                TMPTestPackage::subroutine() for 1 .. $invoked;
            },
            {   ok    => $ok,
                name  => sprintf( 'TMPTestPackage::subroutine called %d %s', $called, PL( 'time', $called ) ),
                depth => -4,
            },
            sprintf( '%s %s', NUMWORDS( $called ), PL( 'time', $called ) )
        );
    };

    $test->( $OK,     0, 0 );
    $test->( $OK,     1, 1 );
    $test->( $OK,     2, 2 );
    $test->( $NOT_OK, 2, 1 );

    throws_ok(
        sub {
            my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->called( '2a' );
        },
        qr/\$called must be an integer >= 0/,
        'exception raised when called is not an integer'
    );

    throws_ok(
        sub {
            my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->called( -1 );
        },
        qr/\$called must be an integer >= 0/,
        'exception raised when called is not an integer'
    );
};

subtest 'expects' => sub {
    subtest 'method' => sub {
        check_tests(
            sub {
                my $m2 = Test::MockPackages::Mock->new( 'TMPTestPackage', 'method' );
                $m2->is_method();
                $m2->expects( 'hello', { one => 'two' } );

                TMPTestPackage->method( 'hello', { one => 'two' } );
            },
            [   {   ok    => 1,
                    name  => 'TMPTestPackage::method expects is correct',
                    depth => 1,
                },
                {   ok    => 1,
                    name  => 'TMPTestPackage::method called 1 time',
                    depth => -4,
                }
            ],
            'expects succeds'
        );

        check_tests(
            sub {
                my $m2 = Test::MockPackages::Mock->new( 'TMPTestPackage', 'method' );
                $m2->is_method();
                $m2->expects( 'hello', { one => 'three' } );

                TMPTestPackage->method( 'hello', { one => 'two' } );
            },
            [   {   ok    => 0,
                    name  => 'TMPTestPackage::method expects is correct',
                    depth => 1,
                },
                {   ok    => 1,
                    name  => 'TMPTestPackage::method called 1 time',
                    depth => -4,
                }
            ],
            'expects fails'
        );
    };

    subtest 'instance' => sub {
        check_tests(
            sub {
                my $m2 = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' );
                $m2->expects( 'hello', { one => 'two' } );

                TMPTestPackage::subroutine( 'hello', { one => 'two' } );
            },
            [   {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine expects is correct',
                    depth => 1,
                },
                {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine called 1 time',
                    depth => -4,
                }
            ],
            'expects succeeds'
        );

        check_tests(
            sub {
                my $m2 = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' );
                $m2->expects( 'hello', { one => 'three' } );

                TMPTestPackage::subroutine( 'hello', { one => 'two' } );
            },
            [   {   ok    => 0,
                    name  => 'TMPTestPackage::subroutine expects is correct',
                    depth => 1,
                },
                {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine called 1 time',
                    depth => -4,
                }
            ],
            'expects fails'
        );
    };

    subtest 'multiple expects' => sub {
        check_tests(
            sub {
                my $m2 =
                    Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->expects( 'first' )->expects( 'second' )
                    ->expects( 'third' );

                TMPTestPackage::subroutine( 'first' );
                TMPTestPackage::subroutine( 'second' );
                TMPTestPackage::subroutine( 'third' );
            },
            [   {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine expects is correct',
                    depth => 1,
                },
                {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine expects is correct',
                    depth => 1,
                },
                {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine expects is correct',
                    depth => 1,
                },
                {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine called 3 times',
                    depth => -4,
                },
            ],
            'all succeed'
        );

        check_tests(
            sub {
                my $m2 =
                    Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->expects( 'first' )->expects( 'second' )
                    ->expects( 'third' );

                TMPTestPackage::subroutine( 'first' );
                TMPTestPackage::subroutine( 'bad' );
                TMPTestPackage::subroutine( 'third' );
            },
            [   {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine expects is correct',
                    depth => 1,
                },
                {   ok    => 0,
                    name  => 'TMPTestPackage::subroutine expects is correct',
                    depth => 1,
                },
                {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine expects is correct',
                    depth => 1,
                },
                {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine called 3 times',
                    depth => -4,
                },
            ],
            'one fails'
        );
    };

    subtest 'not all expects called' => sub {
        check_tests(
            sub {
                my $m2 =
                    Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->expects( 'first' )->expects( 'second' )
                    ->expects( 'third' );

                TMPTestPackage::subroutine( 'first' );
                TMPTestPackage::subroutine( 'second' );
            },
            [   {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine expects is correct',
                    depth => 1,
                },
                {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine expects is correct',
                    depth => 1,
                },
                {   ok    => 0,
                    name  => 'TMPTestPackage::subroutine called 3 times',
                    depth => -4,
                }
            ],
            'too few invokes'
        );
    };

    subtest 'expects with called' => sub {
        check_tests(
            sub {
                my $m2 = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->called( 2 )->expects( 'same' );

                TMPTestPackage::subroutine( 'same' );
                TMPTestPackage::subroutine( 'same' );
            },
            [   {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine expects is correct',
                    depth => 1,
                },
                {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine expects is correct',
                    depth => 1,
                },
                {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine called 2 times',
                    depth => -4,
                }
            ],
            'expects ok'
        );
    };

    subtest 'expects with called' => sub {
        check_tests(
            sub {
                my $m2 = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->called( 2 )->expects( 'same' );

                TMPTestPackage::subroutine( 'same' );
                TMPTestPackage::subroutine( 'bad' );
            },
            [   {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine expects is correct',
                    depth => 1,
                },
                {   ok    => 0,
                    name  => 'TMPTestPackage::subroutine expects is correct',
                    depth => 1,
                },
                {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine called 2 times',
                    depth => -4,
                }
            ],
            'expects ok'
        );
    };

    subtest 'too many calls' => sub {
        my $error;
        check_tests(
            sub {
                eval {
                    my $m2 = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->expects( 'val' );

                    TMPTestPackage::subroutine( 'val' );
                    TMPTestPackage::subroutine( 'val' );
                };
                $error = $EVAL_ERROR;
            },
            [   {   ok    => 1,
                    name  => 'TMPTestPackage::subroutine expects is correct',
                    depth => 2,
                },
                {   ok    => 0,
                    name  => 'TMPTestPackage::subroutine called 1 time',
                    depth => -4,
                }
            ],
            'testing too many calls'
        );

        like( $error, qr/\QTMPTestPackage::subroutine was called 2 times. Only 1 expectation defined/, 'correct exception' );
    };
};

subtest 'returns' => sub {
    subtest 'no returns' => sub {
        my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' );
        is( TMPTestPackage::subroutine(), undef, 'correct return value' );
    };

    subtest 'one value' => sub {
        my @returns;

        check_test(
            sub {
                my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->returns( 'ok' );

                push @returns, [ TMPTestPackage::subroutine() ];
            },
            {   ok    => 1,
                name  => 'TMPTestPackage::subroutine called 1 time',
                depth => -4,
            }
        );

        is_deeply( \@returns, [ [ 'ok' ] ], 'correct return values' );
    };

    subtest 'one value, multiple times' => sub {
        my @returns;

        check_test(
            sub {
                my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->called( 3 )->returns( 'ok' );

                push @returns, [ TMPTestPackage::subroutine() ];
                push @returns, [ TMPTestPackage::subroutine() ];
                push @returns, [ TMPTestPackage::subroutine() ];
            },
            {   ok    => 1,
                name  => 'TMPTestPackage::subroutine called 3 times',
                depth => -4,
            }
        );

        is_deeply( \@returns, [ [ 'ok' ], [ 'ok' ], [ 'ok' ] ], 'correct return values' );
    };

    subtest 'multiple values' => sub {
        my @returns;
        check_test(
            sub {
                my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->returns( 'ok' )
                    ->returns( 'ok2', 'second_val' );
                push @returns, [ TMPTestPackage::subroutine() ];
                push @returns, [ TMPTestPackage::subroutine() ];
            },
            {   ok    => 1,
                name  => 'TMPTestPackage::subroutine called 2 times',
                depth => -4,
            },
            'validate called'
        );

        is_deeply( \@returns, [ [ 'ok' ], [ 'ok2', 'second_val' ] ], 'return values were correct' );
    };

    subtest 'not called enough' => sub {
        subtest 'one return' => sub {
            check_test(
                sub {
                    my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->returns( 'ok' );
                },
                {   ok    => 0,
                    name  => 'TMPTestPackage::subroutine called 1 time',
                    depth => -6,
                },
                'validate called'
            );
        };

        subtest 'multiple returns' => sub {
            check_test(
                sub {
                    my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->returns( 'ok' )
                        ->returns( 'ok2', 'second_val' );
                    TMPTestPackage::subroutine();
                },
                {   ok    => 0,
                    name  => 'TMPTestPackage::subroutine called 2 times',
                    depth => -4,
                },
                'validate called'
            );
        };
    };

    subtest 'called too many times' => sub {
        subtest 'one return setup' => sub {
            my $error;
            check_test(
                sub {
                    eval {
                        my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->returns( 'ok' );
                        TMPTestPackage::subroutine();
                        TMPTestPackage::subroutine();
                    };
                    $error = $EVAL_ERROR;
                },
                {   ok    => 0,
                    name  => 'TMPTestPackage::subroutine called 1 time',
                    depth => -4,
                },
                'validate called'
            );

            like(
                $error,
                qr/\QTMPTestPackage::subroutine was called 2 times. Only 1 return defined/,
                'correct exception raised'
            );
        };

        subtest 'multiple returns setup' => sub {
            my $error;
            check_test(
                sub {
                    eval {
                        my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->returns( 'ok' )
                            ->returns( 'ok2', 'second_val' );
                        TMPTestPackage::subroutine();
                        TMPTestPackage::subroutine();
                        TMPTestPackage::subroutine();
                    };
                    $error = $EVAL_ERROR;
                },
                {   ok    => 0,
                    name  => 'TMPTestPackage::subroutine called 2 times',
                    depth => -4,
                },
                'validate called'
            );

            like(
                $error,
                qr/\QTMPTestPackage::subroutine was called 3 times. Only 2 returns defined/,
                'correct exception raised'
            );
        };
    };

    subtest 'cloning' => sub {
        subtest 'basic ref types' => sub {
            my %hash = ( a => 1, );

            my @array = qw(one);

            my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->returns( \%hash, \@array );
            my ( $return_hash, $return_array ) = TMPTestPackage::subroutine();

            $hash{b} = 2;
            push @array, 'two';

            is_deeply( $return_hash, { a => 1 }, 'hash was properly cloned' );
            is_deeply( $return_array, [ 'one' ], 'array was properly cloned' );
        };

        subtest 'coderef return' => sub {
            my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->returns( sub { 5 } );
            my $coderef = TMPTestPackage::subroutine();

            is( $coderef->(), 5, 'correct CODE returned' );
        };

        subtest 'custom coderef' => sub {
            my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )
                ->returns( returns_code { my ( $a ) = @ARG; $a + 5 } );
            my $retval = TMPTestPackage::subroutine( 10 );
            is( $retval, 15, 'coderef properly executed' );
        };
    };

    subtest 'wantarray' => sub {
        subtest list => sub {
            my $m =
                Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->returns( qw(one two three) )->called( 2 );

            my @vals = TMPTestPackage::subroutine();
            is_deeply( \@vals, [ qw(one two three) ], 'correct list returned' );

            my $value = TMPTestPackage::subroutine();
            is( $value, 3, 'count returned' );
        };

        subtest 'single value' => sub {
            my $m = Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->returns( qw(one) )->called( 2 );

            my @vals = TMPTestPackage::subroutine();
            is_deeply( \@vals, [ qw(one) ], 'correct list returned' );

            my $value = TMPTestPackage::subroutine();
            is( $value, 'one', 'value returned' );
        };
    };
};

subtest '_validate' => sub {
    throws_ok(
        sub {
            Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->called( 2 )->expects( 'first' )
                ->expects( 'second' );
        },
        qr/\Qcalled() cannot be used if expects() or returns() have been defined more than once/,
        'exception when called() used with multiple expects()'
    );

    throws_ok(
        sub {
            Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->called( 2 )->returns( 'first' )
                ->returns( 'second' );
        },
        qr/\Qcalled() cannot be used if expects() or returns() have been defined more than once/,
        'exception when called() used with multiple returns()'
    );

    throws_ok(
        sub {
            Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->never_called()->expects( 'first' )
                ->expects( 'second' );
        },
        qr/\Qnever_called() cannot be used if called(), expects(), or returns() have been defined/,
        'exception when never_called() used with expects()'
    );

    throws_ok(
        sub {
            Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->never_called()->returns( 'first' )
                ->returns( 'second' );
        },
        qr/\Qnever_called() cannot be used if called(), expects(), or returns() have been defined/,
        'exception when never_called() used with returns()'
    );

    throws_ok(
        sub {
            Test::MockPackages::Mock->new( 'TMPTestPackage', 'subroutine' )->never_called()->called( 1 );
        },
        qr/\Qnever_called() cannot be used if called(), expects(), or returns() have been defined/,
        'exception when never_called() used with called()'
    );
};

done_testing();
