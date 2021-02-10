package HTML::TagParser::Query 0.1;

use 5.22.0;
use warnings;
use utf8;
use Encode      qw();
use LWP::Simple qw();
use parent 'HTML::TagParser';
use constant
{
    IsClose => 0,
    TagName => 1,
    AttrStr => 2,
    PostContent   => 3,
    AttrHashCache => 4,
    InrTxtCache   => 5,
    MatchTagIdx   => 6,
    ParentTagIdx  => 7,
      #
    InrHTMLCache => 11,
};


sub fetch {

    my $self = shift;
    my $url  = shift;

    my $content = LWP::Simple::get( $url );
    Carp::croak "&LWP::Simple::get failed: $url"  unless defined $content;

    $self->parse( $content );
}


sub parse {

    my $self = shift;
    my $text = shift;

    my $txtref = \$text;
    if (ref $text) {
        $txtref = $text;

        my $charset = HTML::TagParser::Util::find_meta_charset( $txtref );
        $self->{charset} = $charset;
        unless ($charset && Encode::find_encoding($charset)) {
            $charset = 'utf-8';
        }
        $$txtref = Encode::decode( $charset => $$txtref );
    }

    my $flat = HTML::TagParser::Util::html_to_flat( $txtref );
    Carp::croak "Null HTML document." unless scalar @$flat;

    $self->{flat} = $flat;
    scalar @$flat;
}


# new meth.
sub getElements {

    my $self = shift;
    my $flat = $self->{flat};
    my $out = [];
    for my $i (0 .. $#$flat) {
        next if $flat->[$i]->[IsClose];

        my $elem = (__PACKAGE__ . '::Element')->new( $flat, $i );
        return $elem unless wantarray;

        push( @$out, $elem );
    }
    return unless wantarray;
    @$out;
}


sub getElementsByTagName {

    my $self    = shift;
    my $tagname = lc(shift);

    my $flat = $self->{flat};
    my $out = [];
    for( my $i = 0 ; $i <= $#$flat ; $i++ ) {
        next if ( $flat->[$i]->[TagName] ne $tagname );
        next if $flat->[$i]->[IsClose];

        my $elem = (__PACKAGE__ . '::Element')->new( $flat, $i );

        return $elem unless wantarray;
        push( @$out, $elem );
    }
    return unless wantarray;
    @$out;
}


sub getElementsByAttribute {

    my $self = shift;
    my $key  = lc(shift);
    my $val  = shift;

    my $flat = $self->{flat};
    my $out  = [];
    for ( my $i = 0 ; $i <= $#$flat ; $i++ ) {
        next if $flat->[$i]->[IsClose];

        my $elem = (__PACKAGE__ . '::Element')->new( $flat, $i );

        my $attr = $elem->attributes();
        next unless exists $attr->{$key};

        # 複数 class や複数 id 等の同時指定も扱えるように
        if ($key =~ /^(?:class|name|id)$/) {
            next if ( $attr->{$key} !~ /(^|\s)$val(\s|$)/ );
        } else {
            next if ( $attr->{$key} ne $val );
        }

        return $elem unless wantarray;
        push( @$out, $elem );
    }
    return unless wantarray;
    @$out;
}


# --------------------------------------------------
package HTML::TagParser::Query::Element;

use 5.22.0;
use warnings;
use utf8;
use parent -norequire, 'HTML::TagParser::Element';
use constant
{
    IsClose => 0,
    TagName => 1,
    AttrStr => 2,
    PostContent   => 3,
    AttrHashCache => 4,
    InrTxtCache   => 5,
    MatchTagIdx   => 6,
    ParentTagIdx  => 7,
      #
    InrHTMLCache => 11,
};


# new methods:
sub getElements {
    my $html = shift->subTree;
    return $html->getElements if wantarray;
    scalar $html->getElements;
}
sub getElementsByTagName {
    my $html = shift->subTree;
    return $html->getElementsByTagName(@_) if wantarray;
    scalar $html->getElementsByTagName(@_);
}
sub getElementsByAttribute {
    my $html = shift->subTree;
    return $html->getElementsByAttribute(@_) if wantarray;
    scalar $html->getElementsByAttribute(@_);
}
sub getElementsByClassName {
    my $html = shift->subTree;
    return $html->getElementsByClassName(@_) if wantarray;
    scalar $html->getElementsByClassName(@_);
}
sub getElementsByName {
    my $html = shift->subTree;
    return $html->getElementsByName(@_) if wantarray;
    scalar $html->getElementsByName(@_);
}
sub getElementById {
    my $html = shift->subTree;
    return $html->getElementById(@_) if wantarray;
    scalar $html->getElementById(@_);
}


sub innerText {

    my $self = shift;
    my ( $flat, $cur ) = @$self;
    my $elem = $flat->[$cur];
    return $elem->[InrTxtCache] if defined $elem->[InrTxtCache];

    my $text = $self->SUPER::innerText;
    return unless defined $text;

    $text =~ s#<!--.*?-->##sg;
    $elem->[InrTxtCache] = $text;
}


# new meth.
sub innerHTML {

    my $self = shift;
    my ( $flat, $cur ) = @$self;
    my $elem = $flat->[$cur];
    return $elem->[InrHTMLCache] if defined $elem->[InrHTMLCache];
    return if $elem->[IsClose];
    return if ( defined $elem->[AttrStr] && $elem->[AttrStr] =~ m#/$# );

    my $closing = HTML::TagParser::Util::find_closing( $flat, $cur );

    my $str = $elem->[PostContent];

    for ( $cur += 1; $cur < $closing; $cur++ ) {
        $str .= ($flat->[$cur]->[IsClose]? '</' : '<');
        $str .= $flat->[$cur]->[TagName];
        $str .= ($flat->[$cur]->[AttrStr]? $flat->[$cur]->[AttrStr] : '');
        $str .= '>';
        $str .= $flat->[$cur]->[PostContent];
    }
    $elem->[InrHTMLCache] = $str;
}


sub subTree {

    my $self = shift;
    my ( $flat, $cur ) = @$self;
    my $elem = $flat->[$cur];
    return if $elem->[IsClose];
    my $closing = HTML::TagParser::Util::find_closing($flat, $cur);
    my $list    = [];
    while (++$cur < $closing)
      {
        push @$list, $flat->[$cur];
      }

    return bless { flat => $list }, (__PACKAGE__ =~ s/\:\:Element//r);
}


sub nextSibling {

    my $self = shift;
    my ( $flat, $cur ) = @$self;
    my $elem = $flat->[$cur];

    return undef if $elem->[IsClose];
    my $closing = HTML::TagParser::Util::find_closing($flat, $cur);
    my $next_s = $flat->[$closing+1];
    return undef unless $next_s;
    return undef if $next_s->[IsClose];

    # chg.
    return __PACKAGE__->new( $flat, $closing+1 );
}


sub firstChild {

    my $self = shift;
    my ( $flat, $cur ) = @$self;
    my $elem = $flat->[$cur];
    return undef if $elem->[IsClose];
    my $closing = HTML::TagParser::Util::find_closing($flat, $cur);
    return undef if $closing <= $cur+1;

    # chg.
    return __PACKAGE__->new( $flat, $cur+1 );
}


sub previousSibling {

    my $self = shift;
    my ( $flat, $cur ) = @$self;

    my $idx = $cur-1;
    while ($idx >= 0)
      {
        if ($flat->[$idx][IsClose] && defined($flat->[$idx][MatchTagIdx]))
          {
            $idx = $flat->[$idx][MatchTagIdx];
            next;
          }

        my $closing = HTML::TagParser::Util::find_closing($flat, $idx);

        # chg.
        return __PACKAGE__->new( $flat, $idx )
          if defined $closing and ($closing == $cur || $closing == $cur-1);

        $idx--;
      }
    return undef;
}


sub parentNode {

    my $self = shift;
    my ( $flat, $cur ) = @$self;

    # chg.
    return __PACKAGE__->new( $flat, $flat->[$cur][ParentTagIdx])
        if $flat->[$cur][ParentTagIdx];

    my $ps = $self;
    my $first = $self;

    while (defined($ps = previousSibling($ps))) { $first = $ps; }

    my $parent = $first->[1] - 1;
    return undef if $parent < 0;
    die "parent too short"
        if HTML::TagParser::Util::find_closing($flat, $parent) <= $cur;

    $flat->[$cur][ParentTagIdx] = $parent;

    # chg.
    return __PACKAGE__->new( $flat, $parent )
}


# --------------------------------------------------
package HTML::TagParser::Query::Util;

use 5.22.0;
use warnings;
use utf8;
use HTML::Entities qw();
use constant
{
    IsClose => 0,
    TagName => 1,
    AttrStr => 2,
    PostContent   => 3,
    AttrHashCache => 4,
    InrTxtCache   => 5,
    MatchTagIdx   => 6,
    ParentTagIdx  => 7,
      #
    InrHTMLCache => 11,
};
BEGIN {
    no strict 'refs';
    no warnings 'redefine';

    for my $sub (qw/ xml_unescape html_to_flat find_meta_charset /)
    {
        *{ 'HTML::TagParser::Util::'.$sub }
            = \&{ 'HTML::TagParser::Query::Util::'.$sub };
    }
}


sub xml_unescape {

    my $str = shift;
    return unless defined $str;

    HTML::Entities::decode_entities( $str );
}


sub html_to_flat {

    my $txtref = shift;
    my $flat   = [];
    pos($$txtref) = undef;
    while ( $$txtref =~ m{
        (?:[^<]*) < (?:
            ( / )? ( [^/!<>\s"'=]+ )
            ( (?:"[^"]*"|'[^']*'|[^"'<>])+ )?
        |
            (!-- .*? -- | ![^\-] .*? )
        ) > ([^<]*)
    }sxg ) {

        if (defined $4) {
            my $comment = "<$4>$5";

            # コメントも保持する！
            $flat->[-1][PostContent] .= $comment
                unless $comment =~ /<!DOCTYPE\s/i;

            next;
        }
        my $array = [ $1, $2, $3, $5 ];
        $array->[TagName] =~ tr/A-Z/a-z/;
        push( @$flat, $array );
    }
    $flat;
}


sub find_meta_charset {

    my $txtref = shift;

    if ( $$txtref =~ m{
        <meta \s (?: [^>]+\s )? charset\s*=\s*['"]?\s*([^'"\s/>]+)
    }sxi ) {
        return $1;
    }

    # 上で取れるから不要？
    while ( $$txtref =~ m{
        <meta \s ((?: [^>]+\s )? http-equiv\s*=\s*['"]?Content-Type [^>]+ ) >
    }sxgi ) {
        my $args = $1;
        return $1 if ( $args =~ m# charset=['"]?([^'"\s/]+) #sxgi );
    }

    undef;
}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

HTML::TagParser::Query - Perl extension for blah blah blah

=head1 SYNOPSIS

  use HTML::TagParser::Query;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for HTML::TagParser::Query, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

A. U. Thor, E<lt>a.u.thor@a.galaxy.far.far.awayE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2021 by A. U. Thor

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.32.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
