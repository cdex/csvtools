#!/usr/bin/perl -w

use strict;
use warnings;

use Getopt::Long 'GetOptions';
use Pod::Usage 'pod2usage';
use Text::CSV_XS;
use List::Util qw(first);


sub get_options {
    my $known_pairs = 0; # false
    my $do_not_cache_known_pairs = 0; # false
    my $max_x_gap_for_interpolation = 0; # false
    my $x_column = 'time';
    my $y_column = 'depth';
    my $help = 0; # false
    GetOptions( 'known-pairs|k=s' => \$known_pairs,
		'do-not-cache-known-pairs|c' => \$do_not_cache_known_pairs,
		'max-x-gap-for-interpolation|g=f' => \$max_x_gap_for_interpolation,
		'x-column|x=s' => \$x_column,
		'y-column|y=s' => \$y_column,
		'help|h' => \$help
	);
    
    pod2usage( -verbose  => 2 ) if $help;

    pod2usage( -message => "No valid --known-pairs given." )
	unless $known_pairs;

    return ( 'known-pairs' => $known_pairs,
	     'max-x-gap-for-interpolation' => $max_x_gap_for_interpolation,
	     'do-not-cache-known-pairs' => $do_not_cache_known_pairs,
	     'x-column' => $x_column,
	     'y-column' => $y_column );
}


sub significant_digits_n_sprintf_format {
    my ( $num_str ) = @_;

    $num_str =~ /^[\+\-]?0+$/ and return [ 0, '%.0f' ];
    $num_str =~ /^[\+\-]?0+\.(0+)$/ and return [ 0, '%.' . length( $1 ) . 'f' ];
    $num_str =~ /^[\+\-]?([1-9]\d*)\.?(\d*)$/
	and return [ length( $1 ) + length ( $2 ), '%.' . length( $2 ) . 'f' ];

    $num_str =~ /^[\+\-]?0+[eE][\+\-]?[1-9]\d*$/ and return [ 0, '%.0e' ];
    $num_str =~ /^[\+\-]?0+\.(0+)[eE][\+\-]?[1-9]\d*$/ and return [ 0, '%.' . length( $1 ) . 'e' ];    
    $num_str =~ /^[\+\-]?([1-9])(\d*)\.?(\d*)[eE][\+\-]?[1-9]\d*$/
	and return [ length( $1 ) + length ( $2 ) + length( $3 ), '%.' . ( length( $2 ) + length( $3 ) ) . 'e' ];
}


sub read_known_pairs {
    my %options = @_;

    open my $known_pairs_file, '<', $options{'known-pairs'} or die "Could not open \"$options{'known-pairs'}\" to read";
    my $csv = Text::CSV_XS->new ( { binary => 1 } );
    my ( $x_col_idx, $y_col_idx );

    my @known_pairs_for_intervals = (); # [ [ x, y ], ... ], ...

    while ( my $row = $csv->getline(  $known_pairs_file ) ) {
	unless ( defined( $x_col_idx ) ) {
	    $x_col_idx = first { ${$row}[$_] eq $options{'x-column'} } 0..$#{$row};
	    defined( $x_col_idx ) or die 'No x column in the known pairs';
	    $y_col_idx = first { ${$row}[$_] eq $options{'y-column'} } 0..$#{$row};
	    defined( $y_col_idx ) or die 'No y column in the known pairs';
	    $x_col_idx == $y_col_idx and die 'x-column and y-column are the same';
	    next;
	}

	my $x = ${$row}[$x_col_idx];
	defined( $x ) or die 'No valid x value in known pairs';

	my $y = ${$row}[$y_col_idx];
	defined( $y ) or die 'No valid y value in known pairs';

	unless ( @known_pairs_for_intervals ) {
	    # empty, first
	    push( @known_pairs_for_intervals, [ [ $x, $y ] ] );
	    next;
	}

	my ( $x_prev, $y_prev, $delta_x_prev, $delta_y_prev ) = @{${$known_pairs_for_intervals[-1]}[-1]};
	( $x_prev < $x ) or die "x values are not sorted by ascending order in known pairs: \"$x_prev\" followed by \"$x\"";

	my $delta_x = $x - $x_prev;

	if ( $options{'max-x-gap-for-interpolation'} > 0 && $delta_x > $options{'max-x-gap-for-interpolation'} ) {
	    # break
	    push( @known_pairs_for_intervals, [ [ $x, $y ] ] );
	    next;
	}

	# cont.

	my $delta_y = $y - $y_prev;
	my @y_digits_sprintf = @{ ( sort { ${$a}[0] <=> ${$b}[0] } ( &significant_digits_n_sprintf_format( $y_prev), &significant_digits_n_sprintf_format( $y ) ) )[-1]};

	# delete the previous pair (p) if the pair (p) can be interpolated by this pair (t) and the pair before p (pp)
	if ( $#{$known_pairs_for_intervals[-1]} > 0
	     && $y_prev
	     eq &convert_x2y( $x_prev,
			      ( 'known-pairs' => [ [ ${$known_pairs_for_intervals[-1]}[-2],
						     [ $x, $y,
						       $delta_x_prev + $delta_x, $delta_y_prev + $delta_y,
						       $y_digits_sprintf[1] ] ] ] ) )
	     && $delta_y / $delta_x == $delta_y_prev / $delta_x_prev ) {
	    @y_digits_sprintf = @{ ( sort { ${$a}[0] <=> ${$b}[0] } ( \@y_digits_sprintf, &significant_digits_n_sprintf_format( ${${$known_pairs_for_intervals[-1]}[-2]}[1] ) ) )[-1]};
	    delete( ${$known_pairs_for_intervals[-1]}[-1] );
	    $delta_x = $delta_x_prev + $delta_x;
	    $delta_y = $delta_y_prev + $delta_y;
	}

	push( @{$known_pairs_for_intervals[-1]}, [ $x, $y, $delta_x, $delta_y, $y_digits_sprintf[1] ] );
    }

    close $known_pairs_file or die "Could not close \"$known_pairs_file\" for \"$options{'known-pairs'}\"";

    return \@known_pairs_for_intervals;
}


sub convert_x2y {
    my ( $x, %options ) = @_;

    my @converter = grep { ${${$_}[0]}[0] <= $x && ${${$_}[-1]}[0] >= $x } @{$options{'known-pairs'}};
    return unless $#converter == 0;

    my $max_less = ( grep { ${$_}[0] <= $x } @{$converter[0]} )[-1];
    my $min_more = ( grep { ${$_}[0] >= $x } @{$converter[0]} )[0];

    if ( ${$max_less}[0] == ${$min_more}[0] ) {
	die "Maybe a bug" unless ${$max_less}[0] == $x;
	die "Maybe a bug" unless ${$max_less}[1] == ${$min_more}[1];
	return ${$max_less}[1];
    }

    my $delta_x = ( $x - ${$max_less}[0] ); # 0 <, < 1

    my $delta_y = $delta_x * ${$min_more}[3] / ${$min_more}[2];
    return sprintf( ${$min_more}[4], ${$max_less}[1] + $delta_y );
}


sub process_data {
    my %options = @_;

    my $data_csv = Text::CSV_XS->new ( { binary => 1 } );
    my ( $x_col_idx, $y_col_idx );

    while ( my $row = $data_csv->getline( \*STDIN ) ) {
	unless ( defined( $x_col_idx ) ) {
	    $x_col_idx = first { ${$row}[$_] eq $options{'x-column'} } 0..$#{$row};
	    defined( $x_col_idx ) or die 'No x column in the data';
	    $y_col_idx = first { ${$row}[$_] eq $options{'y-column'} } 0..$#{$row};
	    defined( $y_col_idx ) or splice( @{$row}, $x_col_idx+1, 0, ( $options{'y-column'} ) );
	    $data_csv->print( \*STDOUT, $row );
	    print STDOUT "\n";
	    next;
	}

	my $x = ${$row}[$x_col_idx];

	my $y = &convert_x2y( $x, %options );
	defined( $y ) or next;

	if ( defined( $y_col_idx ) ) {
	    if ( defined( ${$row}[$y_col_idx] ) && ${$row}[$y_col_idx] ne '' && ${$row}[$y_col_idx] ne $y ) {
		warn "y value \"${$row}[$y_col_idx]\" in the data is replaced by \"$y\"";
	    }
	    ${$row}[$y_col_idx] = $y;
	} else {
	    splice( @{$row}, $x_col_idx+1, 0, ( $y ) );
	}
	$data_csv->print( \*STDOUT, $row );
	print STDOUT "\n";
    }
}


sub main {
    my %options = &get_options();

    $options{'known-pairs'} = &read_known_pairs( %options );
    foreach my $i ( @{$options{'known-pairs'}} ) {
	print STDERR "Known pairs (x, y, delta x, delta y): \n";
	foreach my $p ( @$i ) {
	    print STDERR "\t(", join(', ',@$p), ")\n";
	}
    }

    &process_data( %options );
}


&main;
exit 0;


__END__

=head1 SYNOPSIS

B<interpolate.pl> B<-k> F<file> [B<-g> I<gap>] [B<-c>] [B<-i> I<key>=I<value>] [...]

B<interpolate.pl> B<-h>

=head1 DESCRIPTION

This program reads data from the standard input and writes it to the standard output after (1) adding interpolated I<y> values converted from I<x> values and (2) removing records without I<y> values.

The data have to be given in CSV (comma separated values) with the header at the first row, and has a column storing I<x> (See Option B<--io-control> to specify the column).

The I<x>-I<y> conversion is done based on a table given in a file (See Options B<--known-pairs> and B<--max-x-gap-for-interpolation>). When a I<x> cannot be converted into I<y> in a row in the data, the row would be excluded from the output.

=head1 OPTIONS

=over 4

=item B<--known-pairs> F<file>

=item B<-k> F<file>

CSV file containing a series of correlating pairs of I<x> to I<y>. This option is required. The CSV is with the header at the first row and I<x> and I<y> values are stored in columns specified by the header (See Option B<--io-control> to specify the column). The rows have to be ascending-sorted by I<x>. 

=item B<--do-not-cache-known-pairs>

=item B<-c>

Not supported yet. By default, the I<x>-I<y> pairs are read once and kept in the memory. By this option, the pairs would be read as many as the data records, without keeping them in the memory.

=item B<--max-x-gap-for-interpolation> I<gap>

=item B<-g> I<gap>

When a I<x> value in the data is between an adjacent pairs of I<x>-I<y> correlations, the I<x> value would be converted into a I<y> value by linear interpolation. The interpolation should be prevented when the adjacent pairs are not so close. This option gives the maximum I<x> gap between adjacent I<x>-I<y> pairs to allow I<x>-I<y> conversion by interpolating them.

=item B<--x-column> I<column>

=item B<-x> I<column>

Name of the column containing I<x> values in the data and the file of the known pairs. Default is C<time>.

=item B<--y-column> I<column>

=item B<-y> I<column>

Column name for I<y> values similar to B<--x-column>. Default is C<depth>.

=item B<--help>

=item B<-h>

Shows this.

=back

=cut
