#!/usr/bin/perl -w

use strict;
use warnings;

use Getopt::Long 'GetOptions';
use Pod::Usage 'pod2usage';
use Text::CSV_XS;
use List::Util qw(first);


sub get_options {
    my $help = 0; # false
    GetOptions( 'help|h' => \$help );
    pod2usage( -verbose  => 2 ) if $help;
}


sub process_data {
    my @files = @_;

    my $header = undef;

    foreach my $f ( @files ) {
	open IN, '<', $f or next;

	my $h = <IN>;
	if ( defined( $header ) ) {
	    chomp( $h );
	    chomp( $header );
	    $header eq $h or die "Header $h in $f differs from $header";
	} else {
	    $header = $h;
	    print STDOUT $header;
	}

	while ( my $row = <IN> ) {
	    print STDOUT $row;
	}

	close IN or die "Could not close $f";
    }
}


sub main {
    &get_options();
    &process_data( @ARGV ); 
}


&main;
exit 0;


__END__

=head1 SYNOPSIS

B<catfiles.pl> F<file> [F<file> ...]

B<catfiles.pl> B<-h>

=head1 DESCRIPTION

This program concatenates some text files and writes it to the standard output.

The files have to have the header at the first row, and the headers are the same among all the given files.

=head1 OPTIONS

=over 4

=item B<--help>

=item B<-h>

Shows this.

=back

=cut
