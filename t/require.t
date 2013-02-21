use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::Fatal;
use Capture::Tiny qw/capture/;
use lib 't/lib';

plan skip_all => "Your filesystem respects case"
  unless -f 't/lib/foo.pm'; # it's really Foo.pm

use Acme::require::case;

my $err;

$err = exception { require foo };
like( $err, qr/incorrect case/, "foo: caught wrong case" );

$err = exception { require Foo::bar::Baz };
like( $err, qr/incorrect case/, "Foo::bar::Baz: caught wrong case" );

$err = exception { require Foo::Bar::Baz };
is( $err, undef, "Foo::Bar::Baz: required OK" );
ok( $INC{'Foo/Bar/Baz.pm'}, "Foo::Bar::Baz correct in \%INC" );

$err = exception { require 6.0.0 };
like( $err, qr/\Qv6.0.0\E required--this is only/, "6.0.0: failed" );

$err = exception { require 6.0 };
like( $err, qr/\Qv6.0.0\E required--this is only/, "6.0: failed" );

$err = exception { require v6 };
like( $err, qr/\Qv6.0.0\E required--this is only/, "v6: failed" );

$err = exception { require "v6.pm" };
like( $err, qr/Can't find v6\.pm/, "v6.pm: required OK" );

$err = exception { require dies };
like( $err, qr{error at t/lib/dies\.pm}, "dies.pm: caught exception" );

$err = exception { require false };
like(
    $err,
    qr{false\.pm did not return true value},
    "false.pm: caught false return"
);

my @output = split "\n", capture { require wrapper };
like( $output[0], qr/^0 wrapper/, "saw wrapper first in call stack" );
like( $output[1], qr/^1 main /,   "saw main next in call stack" );

done_testing;
# COPYRIGHT
# vim: ts=4 sts=4 sw=4 et:
