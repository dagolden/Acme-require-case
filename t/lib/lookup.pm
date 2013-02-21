package lookup;
use strict;
use warnings;

my $i = 0;
while ( my @call = caller($i) ) {
    print "$i @call[0..7]\n";
    $i++;
}

1;

