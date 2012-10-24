#!/usr/bin/perl
use strict;
use File::Find;

my $now = time;

my($watch, $linkdir, $age) = @ARGV;
$age ||= 3600 * 24 * 30;
mkdir $linkdir, 0777 unless -e $linkdir;

my %exists = map { ($_ => 1) } glob "$linkdir/*";

find(\&want, $watch);

for my $e (keys %exists) {
    unlink $e;
}

sub want {
    /\.(?:avi|mp4|divx|m4v|mov|mkv|flv|wmv)$/i or return;
    my @stat = stat($File::Find::name);
    if ($now - $stat[9] < $age) {
        my $link = "$linkdir/$_";
        if ($exists{$link}) {
            delete $exists{$link};
        } else {
            symlink $File::Find::name, $link;
        }
    }
}

