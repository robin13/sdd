package SDD::Monitor::hdparm;

use warnings;
use strict;
use Params::Validate qw/:all/;
use IPC::Run qw/timeout/;
use User;

=head1 NAME

SDD::Monitor::hdparm - a hdparm specific monitor

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Monitor hard disk spindown state using hdparm

=head1 METHODS

=head2 new

# TODO: RCL 2011-06-06 Document parameters

=cut

sub new {
    my $class = shift;
    my %params = @_;
    
    # Validate the config file
    %params = validate_with(
        params => \%params,
        spec   => {
            loop_sleep   => {
		regex    => qr/^\d*$/,
	    },
	    disks   => {
		type   => ARRAYREF,
		callbacks => { 'Disks exist' => 
		    sub{ 
			my $disks_ref = shift();
			foreach my $disk ( @{ $disks_ref } ){
			    return 0 if ! -e $disk;
			}
			return 1;
		    },
		},
	    },
	    logger => {
		isa => 'Log::Log4perl::Logger',
	    },
        },
    );
    my $self = {};
    $self->{params} = \%params;
    $self->{logger} = $params{logger};

    # TODO: RCL 2011-06-07 This is broken - doesn't actually report user in all cases
    $self->{is_root} = ( User->Login eq 'root' ? 1 : 0 );
    $self->{logger}->info( "You are " . User->Login );
    bless $self, $class;
    
    $self->check_root();

    return $self;
}

=head2 run

Run the Monitor

=cut
sub run {
    my $self = shift;
    
    my $logger = $self->{logger};

    $logger->info( "Monitor started running: hdparm" );

    while( 1 ){
        my $conditions_met = 1;

        # This should be put into an external module, just testing here.
        foreach my $disk( @{ $self->{params}->{disks} } ){
            $logger->debug( "Monitor hdparm testing $disk" );
	    $self->check_root();
	    my @cmd = ( qw/hdparm -C/, $disk );
	    my( $in, $out, $err );
	    if( ! IPC::Run::run( \@cmd, \$in, \$out, \$err, timeout( 10 ) ) ){
		die "Could not run '" . join( ' ', @cmd ) . "': $!";
	    }
	    if( $err ){
		$logger->error( "Monitor hdparm: $err" );
	    }

            if( $out =~ m/drive state is:  active/s ){
                $logger->debug( "Monitor hdparm sees disk is active: $disk" );
                $conditions_met = 0;
            }
        }

        if( $conditions_met ){
            $logger->info( "Monitor hdparm found all disks spun down" );
	    return 1;
        }
        $logger->debug( "Monitor hdparm sleeping $self->{params}->{loop_sleep}" );
        sleep( $self->{params}->{loop_sleep} );
    }
}

sub check_root {
    my $self = shift;
    if( not $self->{is_root} ){
	$self->{logger}->warn( "You are not root. Monitor hdparm will probably not work..." );
    }
}


=head1 AUTHOR

Robin Clarke, C<< <perl at robinclarke.net> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Robin Clarke.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1; # End of SDD
