package Test::MockPackages;
use strict;
use warnings;
use utf8;
use feature qw(state);

our $VERSION = '0.1';

use Carp qw(croak);
use English qw(-no_match_vars);
use Exporter qw(import);
use Test::MockPackages::Mock();
use Test::MockPackages::Package();

our @EXPORT_OK = qw(mock);

sub new {
    my ( $pkg ) = @ARG;

    return bless { '_packages' => {}, }, $pkg;
}

sub pkg {
    my ( $self, $pkg_name ) = @ARG;

    if ( !$pkg_name || ref( $pkg_name ) ) {
        croak( '$pkg_name is required and must be a SCALAR' );
    }

    if ( my $pkg = $self->{_packages}{$pkg_name} ) {
        return $pkg;
    }

    return $self->{_packages}{$pkg_name} = Test::MockPackages::Package->new( $pkg_name );
}

sub mock {
    my ( $config ) = @ARG;

    _must_validate( $config );

    # this while loop is similar to the one found in _must_validate, but I'm explicitly keeping them separate
    # so that we don't end up with partially built and mocked subroutines and methods.
    my $m = Test::MockPackages->new();
    while ( my ( $pkg, $subs_href ) = each %$config ) {
        my $mp = $m->pkg( $pkg );

        while ( my ( $sub, $config_aref ) = each %$subs_href ) {
            my $ms = $mp->mock( $sub );

            for ( my $i = 0; $i < @$config_aref; $i += 2 ) {
                my ( $mock_method, $args_aref ) = @$config_aref[ $i, $i + 1 ];

                my $method = $ms->can( $mock_method );
                $ms->$method( @$args_aref );
            }
        }
    }

    return $m;
}

sub _must_validate {
    my ( $config ) = @ARG;

    if ( ref( $config ) ne 'HASH' ) {
        croak( 'config must be a HASH' );
    }

    while ( my ( $pkg, $subs_href ) = each %$config ) {
        if ( ref( $subs_href ) ne 'HASH' ) {
            croak( "value for $pkg must be a HASH" );
        }

        while ( my ( $sub, $config_aref ) = each %$subs_href ) {
            if ( ref( $config_aref ) ne 'ARRAY' ) {
                croak( "value for ${pkg}::$sub must be an ARRAY" );
            }

            if ( @$config_aref % 2 > 0 ) {
                croak( "value for ${pkg}::$sub must be an even-sized ARRAY" );
            }

            for ( my $i = 0; $i < @$config_aref; $i += 2 ) {
                my ( $mock_method, $args_aref ) = @$config_aref[ $i, $i + 1 ];

                if ( ref( $args_aref ) ne 'ARRAY' ) {
                    croak( "arguments must be an ARRAY for mock method $mock_method in ${pkg}::$sub" );
                }

                if ( !eval { Test::MockPackages::Mock->can( $mock_method ) } ) {
                    croak( "$mock_method is not a capability of Test::MockPackages::Mock in ${pkg}::$sub" );
                }
            }
        }
    }

    return 1;
}

1;

__END__

=head1 NAME

Test::MockPackages - Mocking framework

=head1 SYNOPSIS

 my $m = Test::MockPackages->new();

 # basic mocking
 $m->pkg( 'ACME::Widget' )
   ->mock( 'do_thing' )
   ->expects( $arg1, $arg2 )
   ->returns( $retval );

 # ensure something is never called
 $m->pkg( 'ACME::Widget' )
   ->mock( 'dont_do_other_thing' )
   ->never_called();

 # complex expectation checking
 $m->pkg( 'ACME::Widget' )
   ->mock( 'do_multiple_things' )
   ->is_method()                      # marks do_multiple_things() as a method
   ->expects( $arg1, $arg2 )          # expects & returns for call #1
   ->returns( $retval )
   ->expects( $arg3, $arg4, $arg5 )   # expects & returns for call #2
   ->returns( $retval2 );

 # using a helper sub.
 my $m = mock({
     'ACME::Widget' => {
         do_thing => [
            expects => [ $arg1, $arg2 ],
            returns => [ $retval ],
         ],
         dont_do_other_thing => [
            never_called => [],
         ],
         do_multiple_things => [
            is_method => [],
            expects => [ $arg1, $arg2 ],
            returns => [ $retval ],
            expects => [ $arg3, $arg4, $arg5 ],
            returns => [ $retval2 ],
         ],
     },
     'ACME::ImprovedWidget' => {
         ...
     },
 });

=head1 CONSTRUCTOR

=head2 new( )

Instantiates and returns a new Test::MockPackages object.

You can instantiate multiple Test::MockPackages objects, but it's not recommended you mock the same subroutine/method within the same scope.

 my $m = Test::MockPackages->new();
 $m->pkg('ACME::Widget')->mock('do_thing')->never_called();

 if ( ... ) {
     my $m2 = Test::MockPackages->new();
     $m2->pkg('ACME::Widget')->mock('do_thing')->called(2); # ok
 }

 my $m3 = Test::MockPackages->new();
 $m3->pkg('ACME::Widget')->mock('do_thing')->called(3);        # not ok
 $m3->pkg('ACME::Widget')->mock('do_thing_2')->never_called(); # ok

Both this package, and L<Test::MockPackages::Package> are light-weight packages intended to maintain scope of your mocked subroutines and methods. The bulk of your mocking will take place on L<Test::MockPackages::Mock> objects. See that package for more information.

=head1 METHODS

=head2 pkg( Str $pkg_name ) : Test::MockPackages::Package

Instantiates a new L<Test::MockPackages::Package> object using for C<$pkg_name>. Repeated calls to this method with the same C<$pkg_name> will return the same object.

Return value: A L<Test::MockPackages::Package> object.

=head1 EXPORTED SUBROUTINES

=head2 mock( HashRef $configuration ) : Test::MockPackages

C<mock()> is an exportable subroutine (not exported by default) that allows you to quickly configure your mocks in one call. Behind the scenes, it converts your C<$configuration> to standard OOP calls to the L<Test::MockPackages>, L<Test::MockPackages::Package>, and L<Test::MockPackages::Mock> packages.

C<$configuration> expects the following structure:

 {
     $package_name => {
         $sub_or_method_name => [
            $option => [ 'arg1', ... ],
         ],
     }
     ...
 }

C<$package_name> is the name of your package. This is equvalent to the call:

 $m->pkg( $package_name )
 
C<$sub_or_method_name> is the name of the subroutine or method that you'd like to mock. This is equivalent to:

 $m->pkg( $package_name )
   ->mock( $sub_or_method_name )

The value for C<$sub_or_method_name> should be an ArrayRef. This is so we can support having multiple C<expects> and C<returns>.

C<$option> is the name of one of the methods you can call in L<Test::MockPackages::Mock> (e.g. C<called>, C<never_called>, C<is_method>, C<expects>, C<returns>). The value for C<$option> should always be an ArrayRef. This is equivalent to:

 $m->pkg( $package_name )
   ->mock( $sub_or_method_name )
   ->$option( @{ [ 'arg1', ... ] } );

=head1 SEE ALSO

=over 4

=item L<Test::MockPackages::Mock>

=back

=head1 AUTHOR

Written by Tom Peters <tpeters at synacor.com>.

=head1 COPYRIGHT

Copyright (c), Synacor, Inc., 2016

=cut
