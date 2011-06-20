#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Daemon::Shutdown' ) || print "Bail out!
";
}

diag( "Testing Daemon::Shutdown $Daemon::Shutdown::VERSION, Perl $], $^X" );
