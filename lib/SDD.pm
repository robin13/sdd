package SDD;

use warnings;
use strict;

=head1 NAME

SDD - The great new SDD!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SDD;

    my $foo = SDD->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 function1

=cut

sub new {
    my $class = shift;
    my %params = @_;

    my $self = {};
    
    # TODO: RCL 2011-06-04 Better arg checking
    foreach( keys( %params ) ){
        $self->{$_} = $params{$_};
    }
    bless $self, $class;

    return $self;
}

sub start {
    my $self = shift;
    my $logger = $self->{logger};

    sleep( $self->{startup_buffer} );

    # TODO: RCL 2011-06-04 Load modules here, start threads, etc...
    # This is just a proof of concept for hdparm
    while( 1 ){
        my $shutdown = 1;

        # This should be put into an external module, just testing here.
        foreach my $disk( @{ $self->{disks} } ){
            $logger->debug( "Testing $disk" );
            my $rtn = `hdparm -C $disk`;
            if( $rtn =~ m/drive state is:  active/s ){
                $logger->debug( "Disk is active: $disk" );
                $shutdown = 0;
            }
        }

        if( $shutdown ){
            $logger->info( "Shutting down" );
            if( $self->{test} ){
                $logger->info( "Not really shutting down because running in test mode" );
            }else{
                `shutdown -h now`;
                exit;
            }
        }
        $logger->debug( "Sleeping $self->{loop_sleep}" );
        sleep( $self->{loop_sleep} );
    }
}


=head1 AUTHOR

Robin Clarke, C<< <perl at robinclarke.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sdd at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SDD>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SDD


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=SDD>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/SDD>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/SDD>

=item * Search CPAN

L<http://search.cpan.org/dist/SDD/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Robin Clarke.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of SDD
