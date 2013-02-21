use 5.008001;
use strict;
use warnings;
no warnings qw/once redefine/;

package Acme::require::case;
# ABSTRACT: Make Perl's require case-sensitive
# VERSION

use Carp qw/croak/;
use Path::Tiny;
use Sub::Uplevel ();
use version 0.87;

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
                my ($valid, $actual) = _case_correct( $prefix, $filename );
                if ( $valid ) {
                    $INC{$filename} = $realfilename;
                    # uplevel so calling package looks right
                    my $caller = caller(0);
                    my $packaged_do = eval qq{ package $caller; sub { my \$r = do \$_[0]; \$r } };
                    $result = Sub::Uplevel::uplevel( 2, $packaged_do, $realfilename);
                    last ITER;
                }
                else {
                    croak "$filename has incorrect case (maybe you want $actual instead?)";
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
    my $search = path($prefix); # clone
    my @parts = split qr{/}, $filename;
    my $valid = 1;
    while ( my $p = shift @parts ) {
        if ( grep { $p eq $_ } map { $_->basename } $search->children ) {
            $search = $search->child($p);
        }
        else {
            $valid = 0;
            my ($actual) = grep { lc $p eq lc $_ } map { $_->basename } $search->children;
            $search = $search->child($actual);
        }
    }
    return ($valid, $search->relative($prefix));
}

*CORE::GLOBAL::require = \&require_casely;

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

    perl -MAcme::require::case myprogram.pl

You certainly don't want to run this in production, but it might be good for
your editor's compile command, or in C<PERL5OPT> during testing.

If you're really daring you can stick it in your shell:

    export PERL5OPT=-MAcme::require::case

This module walks the filesystem checking case for every C<require>, so
it is significantly slower than the built-in C<require> function.

Global C<require> overrides are slightly buggy prior to Perl 5.12.  If you
really care about such things, load L<Lexical::SealRequireHints> after
you load this one.

=cut

# vim: ts=4 sts=4 sw=4 et:
