use 5.008001;
use strict;
use warnings;
no warnings qw/once redefine/;

package Acme::require::case;
# ABSTRACT: Make Perl's require case-sensitive

our $VERSION = '0.013';

use B;
use Carp qw/croak/;
use Path::Tiny qw/path/;
use Scalar::Util qw/isvstring/;
use Sub::Uplevel qw/uplevel/;
use version 0.87;

sub require_casely {
    my ($filename) = @_;
    my ( $realfilename, $result, $valid, $actual );

    # Are we checking a version number?
    if ( _looks_like_version($filename) ) {
        my $v = eval { version->new($filename) };
        croak $@ if $@;
        croak "Perl @{[$v->normal]} required--this is only $^V, stopped"
          if $v > $^V;
        return 1;
    }

    # Is it already loaded?
    if ( exists $INC{$filename} ) {
        return 1 if $INC{$filename};
        croak "Compilation failed in require";
    }

    # Absolute or relative?
    if ( path($filename)->is_absolute ) {
        ( $valid, $actual ) = ( 1, $filename );
        $realfilename = path($filename);
    }
    else {
        foreach my $prefix ( map { path($_) } @INC ) {
            $realfilename = $prefix->child($filename);
            if ( $realfilename->is_file ) {
                ( $valid, $actual ) = _case_correct( $prefix, $filename );
                last;
            }
        }
        croak "Can't locate $filename in \@INC (\@INC contains @INC)"
          unless $actual;
    }

    # Valid case or invalid?
    if ($valid) {
        $INC{$filename} = $realfilename;
        # uplevel so calling package looks right
        my $caller = caller(0);
        # deletes $realfilename from %INC after loading it since that's
        # just a proxy for $filename, which is already set above
        my $code = qq{
            package $caller; sub { local %^H; my \$r = do \$_[0]; delete \$INC{\$_[0]}; \$r }
          };
        my $packaged_do = eval $code; ## no critic
        $result = uplevel( 2, $packaged_do, $realfilename );
    }
    else {
        croak "$filename has incorrect case (maybe you want $actual instead?)";
    }

    # Loaded correctly or not?
    if ($@) {
        $INC{$filename} = undef;
        croak $@;
    }
    elsif ( !$result ) {
        delete $INC{$filename};
        croak "$filename did not return a true value";
    }
    else {
        $! = 0;
        return $result;
    }
}

sub _case_correct {
    my ( $prefix, $filename ) = @_;
    my $search = path($prefix);         # clone
    my @parts  = split qr{/}, $filename;
    my $valid  = 1;
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
    return ( $valid, $search->relative($prefix) );
}

sub _looks_like_version {
    my ($v) = @_;
    return 1 if isvstring($v);
    return B::svref_2object( \$v )->FLAGS & ( B::SVp_NOK | B::SVp_IOK );
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

It does not respect any prior C<require> overrides, since it completely
replaces C<require> semantics.  Therefore, it should be loaded as early as
possible, perhaps on the command line:

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
