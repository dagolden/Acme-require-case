use 5.008001;
use strict;
use warnings;
no warnings 'once';

package Acme::require::case;
# ABSTRACT: Make Perl's require case sensitive
# VERSION

use Path::Tiny;

*CORE::GLOBAL::require = \&require_casely;

sub require_casely {
    my ($filename) = @_;
    if ( exists $INC{$filename} ) {
        return 1 if $INC{$filename};
        die "Compilation failed in require";
    }
    my ( $realfilename, $result );
    ITER: {
        foreach my $prefix (@INC) {
            $realfilename = "$prefix/$filename";
            if ( -f $realfilename ) {
                $INC{$filename} = $realfilename;
                $result = do $realfilename;
                last ITER;
            }
        }
        die "Can't find $filename in \@INC";
    }
    if ($@) {
        $INC{$filename} = undef;
        die $@;
    }
    elsif ( !$result ) {
        delete $INC{$filename};
        die "$filename did not return true value";
    }
    else {
        return $result;
    }
}

1;

=for Pod::Coverage method_names_here

=head1 SYNOPSIS

  use Acme::require::case;

=head1 DESCRIPTION

This module might be cool, but you'd never know it from the lack
of documentation.

=head1 USAGE

Good luck!

=head1 SEE ALSO

Maybe other modules do related things.

=cut

# vim: ts=4 sts=4 sw=4 et:
