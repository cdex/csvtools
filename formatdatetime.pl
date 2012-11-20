#!/usr/bin/perl -w

use strict;
use warnings;

use Getopt::Long 'GetOptions';
use Pod::Usage 'pod2usage';
use Text::CSV_XS;
use DateTime::Format::Strptime;


sub get_options {
    my @columns; # undef
    my $format_src = '%FT%T,%N%z'; # undef
    my $format_dst = '%FT%T,%N%z'; # undef
    my $help = 0; # false
    GetOptions( 'column|c=s' => \@columns,
		'source-time-format|s=s' => \$format_src,
		'destination-time-format|d=s' => \$format_dst,
		'help|h' => \$help
	);
    
    pod2usage( -verbose  => 2 ) if $help;

    pod2usage( -message => "No --column given." )
	unless @columns;

    pod2usage( -message => "No differences between --source-time-format and --destination-time-format." )
	if $format_src eq $format_dst;

    die 'Not implemented yet.'; ##

    return ( DateTime::Format::Strptime->new( pattern => $format_src ),
	     DateTime::Format::Strptime->new( pattern => $format_dst ),
	     @columns );
}


sub reformat_time {
    my ( $format_src, $format_dst, $src ) = @_;

    my $int;
    eval {
	$int = $format_src->parse_datetime( $src );
    };
    if ( $@ ) {
	warn "Could not parse \"$src\" as time $format_src: $@";
	return $src; # undef
    }
    return $format_dst->format_datetime( $int );
}


sub process_data {
    my ( $format_src, $format_dst, @cols2select ) = @_;

    my $data_csv = Text::CSV_XS->new ( { binary => 1 } );
    my @indices = ();

    while ( my $row = $data_csv->getline( \*STDIN ) ) {
	unless ( @indices ) {
	    foreach my $c ( @cols2select ) {
		my $i = first { ${$row}[$_] eq $c } 0..$#{$row};
		defined( $i ) and push( @indices, $i );
	    }
	    @indices or die 'No columns selected';
	}
	foreach my $i ( @indices ) {
	    ${$row}[$i] = &reformat_time( $format_src, $format_dst, ${$row}[$i] )
	}
	$data_csv->print( \*STDOUT, $row );
	print STDOUT "\n";
    }
}


sub main {
    &process_data( &get_options() );
}


&main;
exit 0;


__END__

=head1 SYNOPSIS

B<formatdatetime.pl> B<-s> F<format> B<-d> F<format> B<-c> F<column> [B<-c> F<column> ...]

B<formatdatetime.pl> B<-h>

=head1 DESCRIPTION

This program re-formats date-time values in a CSV file read from the standard input and writes it to the standard output.

The data have to be given in CSV (comma separated values) with the header at the first row, and the column names in the header have to be unique.

=head1 OPTIONS

=over 4

=item B<--source-time-format> F<format>

=item B<-s> F<format>

Time format in which values are given specified by [http://search.cpan.org/~drolsky/DateTime-Format-Strptime-1.52/lib/DateTime/Format/Strptime.pm#STRPTIME_PATTERN_TOKENS], not L<strptime(3)> [http://www.unix.com/man-page/FreeBSD/3/strftime/]. Default is C<%FT%T,%N%z>.

=item B<--destination-time-format> F<format>

=item B<-d> F<format>

Time format in which values would be formatted. Default is C<%FT%T,%N%z>.

=item B<--column> F<column>

=item B<-c> F<column>

Name of column containing date-time values to re-format. This required option can be given twice or more.

=item B<--help>

=item B<-h>

Shows this.

=back

=cut
