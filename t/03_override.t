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
my $html = HTML::TagParser::Query->new( join '', <DATA> );
is(
    ($html->getElementsByTagName('div'))[0]->getElementsByClassName('l2')->innerText
        => 'きくけこさし'
);

done_testing;

# ==============================
__DATA__
<html>

<HEAD>
<title>テスト</title>
</HEAD>

<BODY>
<div>

<p class="p l1">あい<span>うえ</span>おか</p>
<p class="p l2">きくけこさし</p>

<div><div><div>
<img src="hoge.jpg" alt="test">
</div></div></div>

</div>
</BODY>
</html>
