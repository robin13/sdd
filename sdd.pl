#!/usr/bin/env perl
=head1 NAME

shutdownmanager.pl

=head1 SYNOPSIS

  shutdownmanager.pl [-config <config file>] 


=head1 DESCRIPTION

Monitors varios system status and decides whether to shutdown the host or not.

=head1 OPTIONS

=over 4

=item --config

Custom configuration.  Default in /etc/shutdown_manager.conf

=item --help

Print a simple help message letting you know how to use get_sap_files
and then exit.
If you are reading this, --help will probably not help you much
further.

=back

=head1 COPYRIGHT

Copyright 2011, Robin Clarke

=head1 AUTHOR

Robin Clarke <perl@robinclarke.net>

=cut

use strict;
use warnings;
use Sys::Load qw( uptime );
use File::stat;
use YAML::Any;
use Getopt::Long;
use Pod::Usage;

my $cli_opts = {};
my $result = GetOptions (
    "logfile=s"        => \$cli_opts->{logfile},
    "startup_buffer=i" => \$cli_opts->{startup_buffer},
    "loop_sleep=i"     => \$cli_opts->{loop_sleep},
    "help"             => \$cli_opts->{help},
    );

if( pod2usage( { -message => $message_text ,
               -exitval => $exit_status  ,  
               -verbose => $verbose_level,  
               -output  => $filehandle } );:w

if( 
my $default_args = {
    logfile        => '/var/log/shutdown_manager.log',
    startup_buffer => 3600,
    loop_sleep     => 60,
};

if( $cli_opts->{help} ){

my $args = {};
foreach( keys( %{ $default_args } ) ){
    $args->{$_} = $cli_opts->{$_} || $default_args->{$_};
}

print Dump( $args );

__END__

my $file = "/var/www/default/cgi-bin/online.txt";
my $uptime_offset = "3600";
my $touch_offset = "300";
my $sleep = "60";
my $logfile = "/var/log/sdmon.log";

my $diff_time = undef;
LOOP:
while( 1 ){
    sleep( $sleep );
    if( uptime() < $uptime_offset ){
        &log( "Staying online because uptime is " . uptime() . "  (Allowed: $uptime_offset)\n" );
        next LOOP;
    }    

    # See if anyone is logged in
    my $users = `users`;
    chomp $users;
    if( $users =~ m/(root|wg|rcl)/ ){
        &log( "Staying online because a user is logged in ($users)\n" );
        next LOOP;
    }

    if( -f $file ){
        $diff_time = time() - stat($file)->mtime;
        print "DiffTime: $diff_time\n";
        if( $diff_time < $touch_offset ){
            &log( "Staying online because dif_time < touch_offset ($diff_time : $touch_offset)\n" );
            next LOOP;
        }
    }else{
        print "File does not exist...\n";
    }
    &shutdown();
}

exit;

sub log{
    my $message = shift;
    if( open( LOG, ">>$logfile" ) ){
        print LOG $message;
        close LOG;
    }else{
        print "Could not open Log: $!\n";
    }
}

sub shutdown{
    my $out;
    $out .= "Shutting down at " . localtime( time ) . "\n";
    $out .= "Uptime:\t" . uptime() . "\n";
    $out .= "DiffTime:\t" . $diff_time . "\n" if( $diff_time );
    $out .= "File does not exist\n" unless( -f $file );
    print $out;
    &log( $out );
    `shutdown -h now`;
}
