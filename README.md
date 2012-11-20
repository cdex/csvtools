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

This tool supports not only numerical values but also
date and time values for _x_ (date-time for _y_ is not supported so far).

selectcols.pl
-------------

Selects columns from a CSV file.

formatdatetime.pl
-----------------

Re-formats date-time values in a CSV file.

catcsv.pl
---------

Concatenates some CSV files to another single CSV file.