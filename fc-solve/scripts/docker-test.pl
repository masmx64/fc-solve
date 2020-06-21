#! /usr/bin/env perl

use strict;
use warnings;
use 5.014;
use autodie;

use Path::Tiny qw/ path /;
use Docker::CLI::Wrapper::Container v0.0.4 ();

my $SYS       = "fedora:32";
my $CONTAINER = "fcsfed";
my $obj       = Docker::CLI::Wrapper::Container->new(
    { container => $CONTAINER, sys => $SYS, },
);

my @deps = map { /^BuildRequires:\s*(\S+)/ ? ("'$1'") : () }
    path("freecell-solver.spec.in")->lines_utf8;
$obj->clean_up();
$obj->run_docker();
$obj->docker( { cmd => [ 'cp', "../source",  "fcsfed:source", ] } );
$obj->docker( { cmd => [ 'cp', "../scripts", "fcsfed:scripts", ] } );
my $script = <<"EOSCRIPTTTTTTT";
set -e -x
curl 'https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-31&arch=x86_64'
sudo dnf -y install cmake gcc gcc-c++ git glibc-devel libcmocka-devel make perl-autodie perl-Path-Tiny python3-pip @deps
sudo pip3 install --prefix=/usr freecell_solver
pip3 install --user freecell_solver
mkdir b
cd b
perl ../scripts/Tatzer
make
FCS_TEST_BUILD=1 perl ../source/run-tests.pl --glob='build*.t'
EOSCRIPTTTTTTT

$obj->exe_bash_code( { code => $script, } );
$obj->clean_up();

__END__

=head1 COPYRIGHT & LICENSE

Copyright 2019 by Shlomi Fish

This program is distributed under the MIT / Expat License:
L<http://www.opensource.org/licenses/mit-license.php>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

=cut
