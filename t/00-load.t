#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'SDD' ) || print "Bail out!
";
}

diag( "Testing SDD $SDD::VERSION, Perl $], $^X" );
