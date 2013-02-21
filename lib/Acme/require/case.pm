use 5.008001;
use strict;
use warnings;
no warnings 'once';

package Acme::require::case;
# ABSTRACT: Make Perl's require case-sensitive
# VERSION

use Carp qw/croak/;
use Path::Tiny;
use version 0.87;

*CORE::GLOBAL::require = \&require_casely;

sub require_casely {
    my ($filename) = @_;
    # looks like a version number check
    if ( my $v = eval { version->parse($filename) } ) {
        if ( $v > $^V ) {
            my $which = $v->normal;
            croak "Perl $which required--this is only $^V, stopped";
        }
        return 1;
    }
    if ( exists $INC{$filename} ) {
        return 1 if $INC{$filename};
        croak "Compilation failed in require";
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
                    croak "$filename has incorrect case at $prefix";
                }
            }
        }
        croak "Can't find $filename in \@INC (\@INC contains @INC)";
    }
    if ( $@ ) {
        $INC{$filename} = undef;
        croak $@;
    }
    elsif ( !$result ) {
        delete $INC{$filename};
        croak "$filename did not return true value";
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

=for Pod::Coverage require_casely

=head1 SYNOPSIS

  use Acme::require::case;

  use MooX::Types::Mooselike::Base; # should be 'MooseLike'

  # dies with: MooX/Types/Mooselike/Base.pm has incorrect case...

=head1 DESCRIPTION

This module overrides C<CORE::GLOBAL::require> to make a case-sensitive check
for its argument.  This prevents C<require foo> from loading "Foo.pm" on
case-insensitive filesystems.

To be effective, it should be loaded as early as possible, perhaps on the
command line:

    perl -MAcme::require:;case myprogram.pl

You certainly don't want to run this in production, but it might be good for
your editor's compile command, or in C<PERL5OPT> during testing.

If you're really daring you can stick it in your shell:

    export PERL5OPT=-MAcme::require::case

This module walks the filesystem checking case for every C<require>, so
it is significantly slower than the built-in C<require> function.

=cut

# vim: ts=4 sts=4 sw=4 et:
