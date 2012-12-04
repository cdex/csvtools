#!/bin/bash

perl datetime2seconds.pl -c time < examples/td-data-example.csv | \
    perl interpolate.pl -k <( perl datetime2seconds.pl -c time < examples/td-example.csv )
