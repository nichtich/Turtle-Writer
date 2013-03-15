package Turtle::Writer;
#ABSTRACT: Write RDF/Turtle documents without non-core package dependencies

use strict;
use warnings;

=head1 SYNOPSIS

  use Turtle::Writer;

  say turtle_statement( 
    "<$uri>",
      "a" => "<http://purl.org/ontology/bibo/Document>",
      "dc:creator" => { # plain literals are escaped
	  	"" => [ "Terry Winograd", "Fernando Flores" ]
      },
      "dc:date" => { "xs:gYear" => "1987" }, # typed literal
      "dc:title" =>
          { en => "Understanding Computers and Cognition" },
      "dc:description" => undef,  # will be ignored
  );

=head1 DESCRIPTION

Turtle::Writer is a lightweight helper module for Perl programs that write RDF
data in Turtle syntax. No non-core packages are required.  Before directly
writing RDF/Turtle by hand, have a look at this module.  Before using this
module, have a look at L<RDF::Trine::Serializer::Turtle> which provides a full
featured serializer for RDF data in Turtle syntax.

By default this module exports four methods: C<turtle_statement>,
C<turtle_literal>, C<turtle_literal_list>, and C<turtle_uri>. This methods may
be handy to directly create serialized RDF from other forms of structured data.
Literal values are escaped and C<undef> is ignored, among other features.

=cut

use Carp;
use Scalar::Util qw(reftype);
use base 'Exporter';

our @EXPORT = qw(turtle_literal turtle_literal_list turtle_statement turtle_uri);

=method turtle_statement ( $subject, $predicate => $object [, ... ] )

Returns a (set of) RDF statements in Turtle syntax. Subject and predicate
parameters must be strings. Object parameters must either be strings or
arrays of strings. This function strips undefined values and empty strings,
but it does not further check or validate parameter values.

=cut

sub turtle_statement {
    my ($subject, %statements) = @_;

    my @s = grep { defined $_ } map {
        my ($p,$o) = ($_,$statements{$_});
        if ( ref($o) ) {
           if (reftype($o) eq 'HASH') {
               $o = [ map { turtle_literal($o->{$_},$_) } keys %$o ];
           }
           if (reftype($o) eq 'ARRAY') {
               $o = join(", ", @$o) if ref($o);
           } else { 
               $o = undef; 
           }
        }
        (defined $o and $o ne '') ? "$p $o" : undef;
    } keys %statements;

	return "" unless @s;

	my $ttl = join(" ;\n" , shift @s, map { "    $_" } @s); 
	if (defined $subject) {
	    return "$subject $ttl .\n";
	} else {
	    return "[ $ttl ] .\n";
	}
}

=method turtle_literal ( $string [ [ lang => ] $lang | [ type => ] $datatype ] )

Returns a literal string escaped in Turtle syntax. You can optionally provide
either a language or a full datatype URI (but their values are not validated).
Returns the empty string instead of a Turtle value, if C<$string> is C<undef>
or the empty string.

=cut

sub turtle_literal {
    my $value = shift;
    my %opt;

    if ( ref( $value ) and ref($value) eq 'ARRAY') {
        return join( ", ", map { turtle_literal( $_, @_ ) } @$value );
    }

    if ( @_ % 2 ) {
        my $v = shift;
        %opt = ($v =~ /^[a-zA-Z0-9-]+$/) ? ( lang => $v ) : ( type => $v ); 
    } else {

        %opt = @_;
        croak "Literal values cannot have both language and datatype"
            if ($opt{lang} and $opt{type});
    }

    return "" if not defined $value or $value eq '';

    my %ESCAPED = ( "\t" => 't', "\n" => 'n', 
        "\r" => 'r', "\"" => '"', "\\" => '\\' );
    $value =~ s/([\t\n\r\"\\])/\\$ESCAPED{$1}/sg;

    $value = qq("$value");

    if ($opt{lang}) {
        return $value.'@'.$opt{lang};
    } elsif ($opt{type}) {
        return $value.'^^<'.$opt{type} .'>';
    }

    return $value;
}

=method turtle_literal_list ( $literal | @array_of_literals | { $language => $literal } )

Returns a list of literal strings in Turtle syntax.

=cut

sub turtle_literal_list {
    if ( ref($_[0]) and ref($_[0]) eq 'HASH') {
        my $hash = $_[0];
        return join( ", ", 
            map { turtle_literal( $hash->{$_}, lang => $_ ) } 
            keys %$hash
        );
    } elsif ( @_ > 1 ) {
        return turtle_literal( \@_ );
    } else {
        return turtle_literal( $_[0] );
    }
}

=method turtle_uri ( $uri )

Returns an URI in Turtle syntax, that is C<< "<$uri>" >>. Returns the 
empty string, if C<$uri> is C<undef>, but C<< <> >> if C<$uri> is the
empty string. In most cases you better directly write C<< "<$uri>" >>.

=cut

sub turtle_uri {
    my $value = shift;
    return "" unless defined $value;
    # my $value = URI->new( encode_utf8( $value ) )->canonical;
    return "<$value>";
}

1;
