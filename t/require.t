use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::Fatal;
use lib 't/lib';

use Acme::require::case;

my $err;

$err = exception { require foo };
like( $err, qr/incorrect case/, "foo: caught wrong case" );

$err = exception { require Foo::bar::Baz };
like( $err, qr/incorrect case/, "Foo::bar::Baz: caught wrong case" );

done_testing;
# COPYRIGHT
# vim: ts=4 sts=4 sw=4 et:
