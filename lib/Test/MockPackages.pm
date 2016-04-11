package Test::MockPackages;
use strict;
use warnings;
use utf8;

our $VERSION = '0.1';

use Carp qw(croak);
use English qw(-no_match_vars);
use Test::MockPackages::Package();

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

=head1 SEE ALSO

=over 4

=item L<Test::MockPackages::Mock>

=back

=head1 AUTHOR

Written by Tom Peters <tpeters at synacor.com>.

=head1 COPYRIGHT

Copyright (c), Synacor, Inc., 2016

=cut
