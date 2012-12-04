csvtools
========

Command line tools to manipulate CSV files.

See `perl interpolate.pl --help` and similar for details.

They require perl modules `Text::CSV_XS` and `DateTime::Format::Strptime`.

interpolate.pl
--------------

Interpolates numerical values for known pairs of values.

### Reason for this tool

Linear interpolation method gives unknown _y_ values for given _x_ values
from known adjacent pairs of _x_ and _y_.
The calculation is so simple and it is easy to have tools to do this.

Sometimes it is needed to prevent such interpolation
at the _x_ intervals where known pairs of _x_ and _y_
at the ends of the intervals are not so close.
The tool takes a maximum _x_ length to allow linear interpolation.

selectcols.pl
-------------

Selects columns from a CSV file.

catfiles.pl
-----------

Concatenates some text files.

### Reason for this tool

It does not accept files with different headers at the first lines,
and prints the header only once at first.

datetime2seconds.pl
-------------------

Converts date-time values in a CSV file to seconds from a time.
