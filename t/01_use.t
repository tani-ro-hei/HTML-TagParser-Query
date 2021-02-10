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

# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl HTML-TagParser-Query.t'
# ------------------------------
our $pkg;
BEGIN {
    our $pkg = 'HTML::TagParser::Query';
    use_ok( $pkg );
}

# ------------------------------
my $html = new_ok( $pkg );
diag( encode '日本語出力もテスト' );  # ←不要

# ------------------------------
is( ref($html) => $pkg );

done_testing;
