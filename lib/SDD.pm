package SDD;

use warnings;
use strict;
use threads;
use YAML::Any qw/Dump LoadFile/;
use Log::Log4perl;
use Params::Validate qw/:all/;
use File::Basename;

=head1 NAME

SDD - Shutdown Daemon

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

This is the core of the shutdown daemon script.

    use SDD;
    my $sdd = SDD->new( %args );
    $sdd->start();

=head1 METHODS

=head2 new

Create new instance of SDD

# TODO: RCL 2011-06-06 Document parameters

=cut

sub new {
    my $class = shift;
   
    my %params = @_;
    # Remove any undefined parameters from the params hash
    map{ delete( $params{$_} ) if not $params{$_} } keys %params;
    
    # Validate the config file
    %params = validate_with(
        params => \%params,
        spec   => {
            config   => {
                callbacks => { 'File exists' => sub{ -f shift } },
                default   => '/etc/sdd.conf',
            },
        },
        allow_extra => 1,
    );
    my $self = {};
        

    # Read the config file
    if( not $params{config} ){
        $params{config} = '/etc/sdd.conf';
    }
    if( not -f $params{config} ){
        die( "Config file $params{config} not found\n" );
    }
    my $file_config = LoadFile( $params{config} );
    delete( $params{config} );

    # Merge the default, config file, and passed parameters
    %params = ( %$file_config, %params );

    my @validate = map{ $_, $params{$_} } keys( %params );
    %params = validate_with(
        params => \%params,
        spec   => 
            {
                log_file => {
                    default   => '/var/log/sdd.log',
                    callbacks => {
                        'Log file is writable' => sub{ 
                            my $filepath = shift;
                            if( -f $filepath ) {
                                return -w $filepath;
                            }
                            else
                            {
                                # Is directory writable
                                return -w dirname( $filepath );
                            }
                        },
                    },
                },
                log_level => {
                    default   => 'INFO',
                    regex     => qr/^(DEBUG|INFO|WARN|ERROR)$/,
                },
                verbose => {
                    default => 0,
                    regex   => qr/^[1|0]$/,
                },
                test => {
                    default => 0,
                    regex   => qr/^[1|0]$/,
                },
                 startup_buffer => {
                    default => 3600,
                    regex   => qr/^\d*$/,
                },
                monitor => {
                    type  => ARRAYREF,
                },
            },
        # A little less verbose than Carp...
        on_fail => sub{ die( shift() ) },
    );

    $self->{params} = \%params;

    bless $self, $class;

    # Set up the logging
    my  $log4perl_conf = sprintf 'log4perl.rootLogger = %s, Logfile', $params{log_level} || 'WARN';
    if( $params{verbose} > 0 ){
        $log4perl_conf .= q(, Screen
            log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
            log4perl.appender.Screen.stderr  = 0
            log4perl.appender.Screen.layout   = Log::Log4perl::Layout::PatternLayout
            log4perl.appender.Screen.layout.ConversionPattern = [%d] %p %m%n
        );

    }

    $log4perl_conf .= q(
        log4perl.appender.Logfile          = Log::Log4perl::Appender::File
        log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Logfile.layout.ConversionPattern = [%d] %p %m%n
    );
    $log4perl_conf .= sprintf "log4perl.appender.Logfile.filename = %s\n", $params{log_file};

    # ... passed as a reference to init()
    Log::Log4perl::init( \$log4perl_conf );
    my $logger = Log::Log4perl->get_logger();
    $self->{logger} = $logger;

    return $self;
}

=head2 start

Start the shutdown daemon

=cut
sub start {
    my $self = shift;
    my $logger = $self->{logger};

    $logger->info( "Started" );

    $logger->info( "Sleeping $self->{params}->{startup_buffer} seconds before starting monitoring" );

    sleep( $self->{params}->{startup_buffer} );

    # TODO: RCL 2011-06-04 Load modules here, start threads, etc...
    # This is just a proof of concept for hdparm
    while( 1 ){
        my $shutdown = 1;

        # This should be put into an external module, just testing here.
        foreach my $disk( @{ $self->{monitor}->{hdparam}->{disks} } ){
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
        $logger->debug( "Sleeping $self->{monitor}->{hdparam}->{loop_sleep}" );
        sleep( $self->{monitor}->{hdparam}->{loop_sleep} );
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

=item * Github

L<https://github.com/robin13/sdd>

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
