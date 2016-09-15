#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use File::Spec ();
use List::MoreUtils qw(none);
use Cwd ();
use File::Path qw/ mkpath rmtree /;
use Env::Path ();
use File::Temp qw/ tempdir /;

# Remove FCS_TEST_BUILD so we won't run the tests with infinite recursion.
if (! delete( $ENV{'FCS_TEST_BUILD'} ) )
{
    plan skip_all => "Skipping because FCS_TEST_BUILD is not set";
}

plan tests => 15;

# Change directory to the Freecell Solver base distribution directory.
my $src_path = $ENV{"FCS_SRC_PATH"};

sub test_cmd
{
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ($cmd, $blurb) = @_;

    my @cmd = (ref($cmd) eq "ARRAY") ? @$cmd : $cmd;

    # These environment variables confuse the input for the harness.
    my $sys_ret =
    do {
        local %ENV = %ENV;
        delete($ENV{HARNESS_VERBOSE});

        system(@cmd);
    };

    if (!ok (!$sys_ret, $blurb))
    {
        Carp::confess("Command [" .
            join(" ", (map { qq/"$_"/ } @cmd)) .
                "] failed! $!."
            );
    }
}

{
    my $temp_dir = tempdir( CLEANUP => 1 );
    my $before_temp_cwd = Cwd::getcwd();

    chdir($temp_dir);
    # TEST
    test_cmd(["cmake", $src_path], "cmake succeeded");

    # TEST
    test_cmd(["make", "dist"], "make dist is successful");

    open my $ver_fh, "<", File::Spec->catfile($src_path, "ver.txt");
    my $version = <$ver_fh>;
    close($ver_fh);
    chomp($version);

    my $base =  "freecell-solver-$version";
    my $tar_arc = "$base.tar";
    my $arc_name = "$tar_arc.xz";

    # The code starting from here makes sure we can run "make dist"
    # inside the freecell-solver-$X.$Y.$Z/ directory generated by the unpacked
    # archive. So we don't have to rename it.

    # TEST
    test_cmd(["tar", "-xvf", $arc_name], "Unpacking the arc name");

    # TEST
    ok (scalar(-d $base), "The directory was created");

    my $orig_cwd = Cwd::getcwd();

    chdir($base);

    mkdir ("build");
    chdir ("build");
    # TEST
    test_cmd(["cmake", ".."],
        "CMaking in the unpacked dir"
    );

    # TEST
    test_cmd(["make", "dist"]);

    # TEST
    test_cmd(["tar", "-xvf", $arc_name],
        "Unpacking the arc name in the unpacked dir"
    );

    # TEST
    ok (scalar(-d $base), "The directory was created again");

    # TEST
    ok (scalar(-f
            File::Spec->catfile(
                File::Spec->curdir(), $base, "CMakeLists.txt"
            )
        ), "CMakeLists.txt exists",
    );

    # TEST
    ok (scalar(-f
            File::Spec->catfile(
                File::Spec->curdir(), $base, "HACKING.txt"
            )
        ), "HACKING.txt exists",
    );

    chdir($orig_cwd);

    my $failing_asciidoc_dir = File::Spec->catdir($orig_cwd, "asciidoc-fail");
    rmtree($failing_asciidoc_dir);
    mkpath($failing_asciidoc_dir);

    my $asciidoc_bin = File::Spec->catfile($failing_asciidoc_dir, "asciidoc");

    {
        open my $out, ">", $asciidoc_bin
            or die "Cannot write to '$asciidoc_bin'";
        print {$out} <<"EOF";
#!$^X
exit(-1);
EOF

        close($out);
    }

    chmod(0755, $asciidoc_bin);

    # Delete the unpacked directory.
    rmtree($base);

    # Now test the rpm building.
    {
        local $ENV{PATH} = $ENV{PATH};

        Env::Path->PATH->Prepend(
            $failing_asciidoc_dir,
        );

        # We need to delete the tar.gz/tar.bz2 because rpmbuild -tb may work
        # on them with the .xz still present.
        unlink(map { "$tar_arc.$_" } qw/bz2 gz/);

        # TEST
        ok (scalar(-e $arc_name),
            "Archive exists."
        );

        open my $tar_fh, "-|", "tar", "-tvf", $arc_name
            or die "Could not open Tar '$arc_name' for opening.";

        my @tar_lines = (<$tar_fh>);
        close($tar_fh);

        chomp(@tar_lines);

        # TEST
        ok ((none { m{/config\.h\z} } @tar_lines),
            "Archive does not contain config.h files");

        # TEST
        ok ((none { m{/freecell-solver-range-parallel-solve\z} } @tar_lines),
            "Archive does not contain the range solver executable");

        # TEST
        ok ((none { m{/libfreecell-solver\.a\z} } @tar_lines),
            "Archive does not contain libfreecell-solver.a");

        # TEST
        test_cmd ("rpmbuild -tb $arc_name 2>/dev/null",
            "rpmbuild -tb is successful."
        );
    }

    rmtree($failing_asciidoc_dir);

    chdir ($before_temp_cwd);
}

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2009 Shlomi Fish

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


