package Test::MockPackages::Mock;
use strict;
use warnings;
use utf8;

=head1 NAME

Test::MockPackages::Mock - handles mocking of individual methods and subroutines.

=head1 SYNOPSIS

 my $m = Test::MockPackages::Mock->new( $package, $subroutine )
    ->is_method()
    ->expects( $arg1, $arg2 )
    ->returns( 'ok' );

=head1 DESCRIPTION

Test::MockPackages::Mock will mock an individual subroutine or method on a given package. You most likely won't initialize new C<Test::MockPackages::Mock> objects directly, instead you
should have L<Test::MockPackages> create them for you using the C<mock()> method.

In short this package will allow you to verify that a given subroutine/method is: 1) called the correct number of times (see C<called()>, C<never_called()>, and C<is_method>), 2) called with the correct arguments (see C<expects()>), and 3) returns values you define (C<returns()>).

=cut

use Carp qw(croak);
use Const::Fast qw(const);
use English qw(-no_match_vars);
use Exporter qw(import);
use Lingua::EN::Inflect qw(PL);
use List::Util qw(max);
use Scalar::Util qw(looks_like_number weaken);
use Storable qw(dclone);
use Test::More;
use parent qw(Test::Builder::Module);

my $CLASS = __PACKAGE__;

const my @GLOB_TYPES => qw(SCALAR HASH ARRAY HANDLE FORMAT IO);

=head1 CONSTRUCTORS

=head2 new( Str $package_name, Str $name )

Instantiates a new Test::MockPackage::Mock object. C<$name> is the subroutine or method that you intend to mock in the named C<$package_name>.

=cut

sub new {
    my ( $pkg, $package_name, $name ) = @ARG;

    my $full_name = "${package_name}::$name";
    my $original = exists &$full_name ? \&$full_name : undef;

    my $self = bless {
        _allow_eval       => 0,
        _called           => undef,
        _expects          => undef,
        _full_name        => $full_name,
        _invoke_count     => 0,
        _is_method        => 0,
        _name             => $name,
        _never            => 0,
        _original_coderef => $original,
        _package_name     => $package_name,
        _returns          => undef,
        _corrupt          => 0,
    }, $pkg;

    $self->_initialize();

    return $self;
}

=head1 METHODS

=head2 called( Int $called ) : Test::MockPackage::Mock

Will ensure that the subroutine/method has been called C<$called> times. This method cannot be used in combination with C<never_called()>.

You can combined this method with C<expects()> and/or C<returns()> to support repeated values. For example:
    $m->expects($arg1, $arg2)
      ->expects($arg1, $arg2)
      ->expects($arg1, $arg2)
      ->expects($arg1, $arg2)
      ->expects($arg1, $arg2);

can be simplified as:
    $m->expects($arg1, $arg2)
      ->called(5);

Return value: Returns itself to support the fluent interface.

=cut

sub called {
    my ( $self, $called ) = @ARG;

    if ( !looks_like_number( $called ) || $called < 0 ) {
        croak( '$called must be an integer >= 0' );
    }

    $self->{_called} = $called;

    return $self->_validate();
}

=head2 never_called() : Test::MockPackage::Mock

Ensures that this subroutine/method will never be called. This method cannot be used in combination with C<called()>, C<expects()>, or C<returns()>.

Return value: Returns itself to support the fluent interface.

=cut

sub never_called {
    my ( $self ) = @ARG;

    $self->{_never} = 1;

    return $self->_validate();
}

=head2 is_method() : Test::MockPackage::Mock

Specifies that the mocked subroutine is a method. When setting up expectations using C<expects()>, it will ignore the first value which is typically the object.

Return value: Returns itself to support the fluent interface.

=cut

sub is_method {
    my ( $self ) = @ARG;

    $self->{_is_method} = 1;

    return $self->_validate();
}

=head2 expects( Any @expects ) : Test::MockPackage::Mock

Ensures that each invocation has the correct arguments passed in. If the subroutine/method will be called multiple times, you can call C<expects()> multiple times. If
the same expectation will be used repeatedly, you can use this in conjunction with C<called()>. See L<called()> for more information.

If you are mocking a method, be sure to call C<is_method()> at some point.

When the C<Test::MockPackages::Mock> object goes out of scope, we'll test to make sure that the subroutine/method was called the correct number of times based on the number
of times that C<expects()> was called, unless C<called()> is specified.

Return value: Returns itself to support the fluent interface.

=cut

sub expects {
    my ( $self, @expects ) = @ARG;

    push @{ $self->{_expects} }, \@expects;

    return $self->_validate();
}

=head2 returns( Any @returns ) : Test::MockPackage::Mock

This method sets up what the return values should be. If the return values will change with each invocation, you can call this method multiple times. 
If this method will always return the same values, you can call C<returns()> once, and then pass in an appropriate value to C<called()>.

When the C<Test::MockPackages::Mock> object goes out of scope, we'll test to make sure that the subroutine/method was called the correct number of times based on the number
of times that C<expects()> was called, unless C<called()> is specified.

Values passed in will be returned verbatim. A deep clone is also performed to accidental side effects aren't tested.

C<wantarray> will be used to try and determine if a list or a single value should be returned. If C<@returns> contains a single element and C<wantarray> is false, the value at index 0 will be returned. Otherwise,
a list will be returned.

If you'd rather have the value of a custom CODE block returned, you can pass in a CodeRef wrapped using a returns_code from the L<Test::MockPackages::Returns> package.

 use Test::MockPackages::Returns qw(returns_code);
 ...
 $m->expects( $arg1, $arg2 )
   ->returns( returns_code {
       my (@args) = @ARG;

       return join ', ', @args;
   } );

Return value: Returns itself to support the fluent interface.

=cut

sub returns {
    my ( $self, @returns ) = @ARG;

    # dclone will remove the bless on the CodeRef.
    if ( @returns == 1 && eval { $returns[ 0 ]->isa( 'Test::MockPackages::Returns' ) } ) {
        push @{ $self->{_returns} }, \@returns;
    }
    else {
        # this should be safe since we are just doing a dclone(). According to the Storable POD, the eval is only dangerous
        # when the input may contain malicious data (i.e. the frozen binary data).
        local $Storable::Deparse = 1;    ## no critic (Variables::ProhibitPackageVars)
        local $Storable::Eval    = 1;    ## no critic (Variables::ProhibitPackageVars)

        push @{ $self->{_returns} }, dclone( \@returns );
    }

    return $self->_validate();
}

# ----
# private methods
# ----

# _initialize( ) : Bool
#
# This is where everythign is setup. We override the subroutine/method being mocked and replace it with a CodeRef
# that will perform the various expects checking and return values based on how returns were setup.
#
# Return value: True

sub _initialize {
    my ( $self ) = @ARG;

    my $test = $CLASS->builder;

    weaken $self;
    my $mock = sub {
        my ( @got ) = @ARG;

        # _invoke_count keeps track of how many times this subroutine/method was called
        my $invoke_number = ++$self->{_invoke_count};

        # $i is the current invocation
        my $i = $invoke_number - 1;

        # the first value passed into the method is the object itself. ignore that.
        if ( $self->{_is_method} ) {
            shift @got;
        }

        # setup the expectations
        if ( my $expects = $self->{_expects} ) {
            my $n_expects = scalar( @$expects );
            my $expected;
            if ( $n_expects == 1 && defined( $self->{_called} ) ) {
                $expected = $expects->[ 0 ];
            }
            elsif ( $i >= $n_expects ) {
                croak(
                    sprintf(
                        '%s was called %d %s. Only %d %s defined',
                        $self->{_full_name}, $invoke_number,    PL( 'time', $invoke_number ),
                        $n_expects,          PL( 'expectation', $n_expects )
                    )
                );
            }
            else {
                $expected = $expects->[ $i ];
            }

            local $Test::Builder::Level = $Test::Builder::Level + 6;    ## no critic (Variables::ProhibitPackageVars)
            is_deeply( \@got, $expected, "$self->{_full_name} expects is correct" );
        }

        # setup the return values
        my @returns;
        if ( my $returns = $self->{_returns} ) {
            my $n_returns = scalar @$returns;

            if ( $n_returns == 1 && defined( $self->{_called} ) ) {
                @returns = @{ $returns->[ 0 ] };
            }
            elsif ( $i >= $n_returns ) {
                croak(
                    sprintf(
                        '%s was called %d %s. Only %d %s defined',
                        $self->{_full_name}, $invoke_number, PL( 'time', $invoke_number ),
                        $n_returns,          PL( 'return',   $n_returns )
                    )
                );
            }
            else {
                @returns = @{ $returns->[ $i ] };
            }
        }
        else {
            return;
        }

        if ( @returns == 1 && eval { $returns[ 0 ]->isa( 'Test::MockPackages::Returns' ) } ) {
            return $returns[ 0 ]->( @got );
        }

        # return the first element if only one return defined and a wantarray is false.
        return !wantarray && scalar( @returns ) == 1 ? $returns[ 0 ] : @returns;
    };

    do {
        no strict qw(refs);          ## no critic (TestingAndDebugging::ProhibitNoStrict)
        no warnings qw(redefine);    ## no critic (TestingAndDebugging::ProhibitNoWarnings)
        my $full_name = $self->{_full_name};
        *$full_name = $mock;
    };

    return 1;
}

# _validate( ) Test::MockPackages::Mock, Throws '...'
#
# Validates that the mock has been properly configured up to this point. If any errors
# were detected, raise an exception.
#
# Return value: Returns itself to support the fluent interface.

sub _validate {
    my ( $self ) = @ARG;

    my $called    = $self->{_called};
    my $never     = $self->{_never};
    my $n_expects = $self->{_expects} ? @{ $self->{_expects} } : 0;
    my $n_returns = $self->{_returns} ? @{ $self->{_returns} } : 0;

    if ( $called ) {

        # breaking into two if statements so Devel::Cover marks this condition as covered
        if ( $n_expects > 1 || $n_returns > 1 ) {
            $self->{_corrupt} = 1;
            croak( 'called() cannot be used if expects() or returns() have been defined more than once' );
        }
    }

    if ( $never ) {

        # breaking into two if statements so Devel::Cover marks this condition as covered
        if ( $called || $n_expects || $n_returns ) {
            $self->{_corrupt} = 1;
            croak( 'never_called() cannot be used if called(), expects(), or returns() have been defined' );
        }
    }

    return $self;
}

# _expected_invocations( ) : Maybe[Int]
#
# Calculates how many times a subroutine/method is expected to be called.
#
# Return value: an integer value on the number of times the subroutine/method should be called.

sub _expected_invocations {
    my ( $self ) = @ARG;

    return 0 if $self->{_never};
    return $self->{_called} if defined $self->{_called};

    my $n_expects = $self->{_expects} ? @{ $self->{_expects} } : 0;
    my $n_returns = $self->{_returns} ? @{ $self->{_returns} } : 0;
    my $max = max( $n_expects, $n_returns );

    return $max >= 1 ? $max : undef;
}

# DESTROY( )
#
# DESTROY is used to the original subroutine/method back into place and perform any final expectation checking.

sub DESTROY {
    no strict qw(refs);          ## no critic (TestingAndDebugging)
    no warnings qw(redefine);    ## no critic (TestingAndDebugging)

    my ( $self ) = @ARG;

    my $full_name = $self->{_full_name};

    my $expected_invocations = $self->_expected_invocations;
    if ( !$self->{_corrupt} && defined $expected_invocations ) {
        local $Test::Builder::Level = $Test::Builder::Level + 6;    ## no critic (Variables::ProhibitPackageVars)
        $CLASS->builder->is_num( $self->{_invoke_count},
            $expected_invocations,
            sprintf( '%s called %d %s', $full_name, $expected_invocations, PL( 'time', $expected_invocations ) ) );
    }

    # if we have an original CodeRef, put it back in place.
    if ( my $original = $self->{_original_coderef} ) {
        *$full_name = $original;
    }

    # otherwise, remove the CodeRef from the symbol table, but make sure the other types are
    # left intact.
    else {
        my %copy;
        $copy{$ARG} = *$full_name{$ARG} for grep { defined *$full_name{$ARG} } @GLOB_TYPES;
        undef *$full_name;
        *$full_name = $copy{$ARG} for keys %copy;
    }

    return;
}

1;

__END__

=head1 AUTHOR

Written by Tom Peters <tpeters at synacor.com>.

=head1 COPYRIGHT

Copyright (c), Synacor, Inc., 2016

=cut
