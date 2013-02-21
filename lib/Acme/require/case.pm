use 5.008001;
use strict;
use warnings;
no warnings 'once';

package Acme::require::case;
# ABSTRACT: Make Perl's require case sensitive
# VERSION

use Path::Tiny;
use version;

*CORE::GLOBAL::require = \&require_casely;

sub require_casely {
    my ($filename) = @_;
    # looks like a version number check
    if ( my $v = eval { version->parse($filename) } ) {
        if ( $v > $^V ) {
            my $which = $v->normal;
            die "Perl $which required--this is only $^V, stopped";
        }
        return 1;
    }
    if ( exists $INC{$filename} ) {
        return 1 if $INC{$filename};
        die "Compilation failed in require";
    }
    my ( $realfilename, $result );
    ITER: {
        foreach my $prefix ( map { path($_) } @INC ) {
            $realfilename = $prefix->child($filename);
            if ( $realfilename->is_file ) {
                if ( _case_correct( $prefix, $filename ) ) {
                    $INC{$filename} = $realfilename;
                    $result = do $realfilename;
                    last ITER;
                }
                else {
                    die "$filename has incorrect case at $prefix";
                }
            }
        }
        die "Can't find $filename in \@INC (\@INC contains @INC)";
    }
    if ( $@ || $! ) {
        $INC{$filename} = undef;
        die $@ ? $@ : $!;
    }
    elsif ( !$result ) {
        delete $INC{$filename};
        die "$filename did not return true value";
    }
    else {
        return $result;
    }
}

sub _case_correct {
    my ( $prefix, $filename ) = @_;
    my @parts = split qr{/}, $filename;
    while ( my $p = shift @parts ) {
        if ( grep { $p eq $_ } map { $_->basename } $prefix->children ) {
            $prefix = $prefix->child($p);
        }
        else {
            return 0;
        }
    }
    return 1;
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
