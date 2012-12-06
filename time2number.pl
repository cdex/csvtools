#!/usr/bin/perl -w

use strict;
use warnings;

use Getopt::Long 'GetOptions';
use Pod::Usage 'pod2usage';
use Text::CSV_XS;
use List::Util qw(first);
use DateTime::Format::Strptime;


sub get_options {
    my @columns; # undef
    my $format = '%FT%T,%N%z';
    my $epoch = '1970-01-01T00:00:00,0+0000';
    my $help = 0; # false
    GetOptions( 'column|c=s' => \@columns,
		'time-format|f=s' => \$format,
		'epoch|e=s' => \$epoch,
		'help|h' => \$help
	);
    
    pod2usage( -verbose  => 2 ) if $help;

    pod2usage( -message => "No --column given." )
	unless @columns;

    my $format_strptime = DateTime::Format::Strptime->new( pattern => $format );
    my $epoch_datetime;
    eval {
	$epoch_datetime = $format_strptime->parse_datetime( $epoch );
    };
    if ( $@ ) {
        pod2usage( -message => "Could not parse \"$epoch\" as time $format: $@" );
    }

    return ( $format_strptime, $epoch_datetime, @columns );
}


sub time2seconds {
    my ( $format, $epoch, $val ) = @_;

    my $datetime;
    eval {
	$datetime = $format->parse_datetime( $val );
    };
    if ( $@ ) {
	warn "Could not parse \"$val\" as time $format: $@";
	return $val;
    }
    unless ( defined( $datetime ) ) {
	warn "Could not parse \"$val\" as time $format";
	return $val;
    }
    my $delta = $datetime->subtract_datetime_absolute( $epoch );
    return ( $delta->is_negative() ? '-' : '' ) . sprintf( "%d.%09d", $delta->seconds, $delta->nanoseconds );
}


sub process_data {
    my ( $format, $epoch, @cols2select ) = @_;

    my $data_csv = Text::CSV_XS->new ( { binary => 1 } );
    my @indices = ();

    while ( my $row = $data_csv->getline( \*STDIN ) ) {
	unless ( @indices ) {
	    foreach my $c ( @cols2select ) {
		my $i = first { ${$row}[$_] eq $c } 0..$#{$row};
		defined( $i ) and push( @indices, $i );
	    }
	    @indices or die 'No columns selected';
	} else {
	    foreach my $i ( @indices ) {
		${$row}[$i] = &time2seconds( $format, $epoch, ${$row}[$i] )
	    }
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

B<time2number.pl> B<-f> F<format> B<-e> F<epoch> B<-c> F<column> [B<-c> F<column> ...]

B<time2number.pl> B<-h>

=head1 DESCRIPTION

This program converts date-time values in a CSV file read from the standard input to seconds from a time F<epoch> and writes them to the standard output.

The data have to be given in CSV (comma separated values) with the header at the first row, and the column names in the header have to be unique.

=head1 OPTIONS

=over 4

=item B<--time-format> F<format>

=item B<-f> F<format>

Time format in which values are given specified by [http://search.cpan.org/~drolsky/DateTime-Format-Strptime-1.52/lib/DateTime/Format/Strptime.pm#STRPTIME_PATTERN_TOKENS], not L<strptime(3)> [http://www.unix.com/man-page/FreeBSD/3/strftime/]. Default is C<%FT%T,%N%z>.

=item B<--epoch> F<epoch>

=item B<-e> F<epoch>

The time given in the format of F<format>, which will be subtracted from time values to convert them to seconds. Default is C<1970-01-01T00:00:00,0+0000>.

=item B<--column> F<column>

=item B<-c> F<column>

Name of column containing date-time values to convert. This required option can be given twice or more.

=item B<--help>

=item B<-h>

Shows this.

=back

=cut
