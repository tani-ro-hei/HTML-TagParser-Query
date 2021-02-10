use strict;
use warnings;
use utf8;
use Test::More;
use lib 'C:/Users/ippei/Dropbox/ws/lib';
use Encode::Locale;
BEGIN {
    binmode $_, ':encoding(console_in)'
        for \(*STDIN, *STDOUT, *STDERR); }
use Encode qw();
sub encode { Encode::encode(console_in => $_[0]) }

# ------------------------------
use HTML::TagParser::Query;
use FindBin;
my $html = HTML::TagParser::Query->new( "$FindBin::Bin/sample2/a.html" );
is( $html->{flat}->[12]->[0] => '/' );

# ------------------------------
is( $html->{flat}->[12]->[1] => 'h1' );

done_testing;
