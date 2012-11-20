#!/usr/bin/perl -w

use strict;
use warnings;

use Getopt::Long 'GetOptions';
use Pod::Usage 'pod2usage';
use Text::CSV_XS;
use List::Util qw(first);


sub get_options {
    my @columns; # undef
    my $help = 0; # false
    GetOptions( 'column|c=s' => \@columns,
		'help|h' => \$help
	);
    
    pod2usage( -verbose  => 2 ) if $help;

    pod2usage( -message => "No --column given." )
	unless @columns;

    return @columns;
}


sub process_data {
    my @cols2select = @_;

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
	my @out = ();
	foreach my $i ( @indices ) {
	    push( @out, defined( $i ) ? ${$row}[$i] : undef );
	}
	$data_csv->print( \*STDOUT, \@out );
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

B<selectcols.pl> B<-c> F<column> [B<-c> F<column> ...]

B<selectcols.pl> B<-h>

=head1 DESCRIPTION

This program selects some column(s) from a CSV file read from the standard input and writes it to the standard output.

The data have to be given in CSV (comma separated values) with the header at the first row, and the column names in the header have to be unique.

=head1 OPTIONS

=over 4

=item B<--column> F<column>

=item B<-c> F<column>

Column name to select. This required option can be given twice or more.

=item B<--help>

=item B<-h>

Shows this.

=back

=cut
