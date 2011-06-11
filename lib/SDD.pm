package SDD;

use warnings;
use strict;
use threads;
use YAML::Any qw/Dump LoadFile/;
use Log::Log4perl;
use Params::Validate qw/:all/;
use File::Basename;
use IPC::Run;
use User;

=head1 NAME

SDD - Shutdown Daemon

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';


=head1 SYNOPSIS

This is the core of the shutdown daemon script.

    use SDD;
    my $sdd = SDD->new( %args );
    $sdd->start();

=head1 METHODS

=head2 new

Create new instance of SDD

=head3 PARAMS

=over 2

=item log_file <Str>

Path to log file
Default: /var/log/sdd.log'

=item log_level <Str>

Logging level (from Log::Log4perl).  Valid are: DEBUG, INFO, WARN, ERROR
Default: INFO

=item verbose 1|0

If enabled, logging info will be printed to screen as well
Default: 0

=item test 1|0

If enabled shutdown will not actually be executed.
Default: 0

=item sleep_before_run <Int>

Time in seconds to sleep before running the monitors.
e.g. to give the system time to boot, and not to shut down before users
have started using the freshly started system.
Default: 3600

=item exit_after_trigger 1|0

If enabled will exit the application after a monitor has triggered.
Normally it is a moot point, because if a monitor has triggered, then a shutdown
is initialised, so the script will stop running anyway.
Default: 0

=item monitor HASHREF

A hash of monitor definitions.  Each hash key must map to a Monitor module, and
contain a hash with the parameters for the module.

=item use_sudo 1|0

Use sudo for shutdown

   sudo shutdown -h now

Default: 0

=item shutdown_binary <Str>

The full path to the shutdown binary
Default: /sbin/shutdown

=back

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
                sleep_before_run => {
                    default => 3600,
                    regex   => qr/^\d*$/,
                },
                exit_after_trigger => {
                    default => 0,
                    regex   => qr/^[1|0]$/,
                },
                use_sudo => {
                    default => 0,
                    regex   => qr/^[1|0]$/,
                },
                shutdown_binary => {
                    default => '/sbin/shutdown',
                    type => 'SCALAR',
                    callbacks => {
                        'Shutdown binary exists' => sub{ -x shift() },
                    },
                }, 
                monitor => {
                    type  => HASHREF,
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
    

    $self->{is_root} = ( User->Login eq 'root' ? 1 : 0 );
    $self->{logger}->info( "You are " . User->Login );

    if( not $self->{is_root} ){
	$self->{logger}->warn( "You are not root. SDD will probably not work..." );
    }

    # Load the monitors
    my %monitors;
    foreach my $monitor_name( keys( %{ $params{monitor} } ) ){
	eval{
	    my $monitor_package = 'SDD::Monitor::' . $monitor_name;
	    my $monitor_path = 'SDD/Monitor/' . $monitor_name . '.pm';
	    require $monitor_path;

	    $monitors{$monitor_name} = $monitor_package->new( %{ $params{monitor}->{$monitor_name} } );
	};
	if( $@ ){
	    die( "Could not initialise monitor: $monitor_name\n$@\n" );
	}
    }
    $self->{monitors} = \%monitors;

    return $self;
}

=head2 start

Start the shutdown daemon

=cut
sub start {
    my $self = shift;
    my $logger = $self->{logger};

    $logger->info( "Started" );

    $logger->info( "Sleeping $self->{params}->{sleep_before_run} seconds before starting monitoring" );

    sleep( $self->{params}->{sleep_before_run} );
    
    my $monitor = $self->{monitors}->{hdparm};

    $monitor->run();
    $logger->info( "Shutting down" );
    if( $self->{test} ){
	$logger->info( "Not really shutting down because running in test mode" );
    }else{
        # Do the actual shutdown
        my @cmd = ( $self->{params}->{shutdown_binary}, '-h', 'now' );
        if( $self->{params}->{use_sudo} ){
            unshift( @cmd, 'sudo' );
        }
        my( $in, $out, $err );
	if( ! IPC::Run::run( \@cmd, \$in, \$out, \$err, IPC::Run::timeout( 10 ) ) ) {
	    $logger->error( "Could not run '" . join( ' ', @cmd ) . "': $!" );
	}
	if( $err ) {
	    $logger->error( "Monitor hdparm could not shutdown: $err" );
	}
        if( $self->{params}->{exit_after_trigger} ){
            exit;
        }
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
