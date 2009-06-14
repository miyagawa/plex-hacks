#!/usr/bin/perl
use strict;
use warnings;
use Encode;
use File::Basename qw(basename);
use LWP::Simple;
use File::Path;
use File::Spec;
use Cwd;

our $BaseDir = "$ENV{HOME}/Movies/Plex";
mkdir $BaseDir, 0777 unless -e $BaseDir;

if ($ARGV[0] eq '-t') { selftest() }

my $aliases = {};
if (open my $fh, "<:utf8", "$ENV{HOME}/.plexshowaliases") {
    while (<$fh>) {
        chomp;
        my($orig, $alias) = split /,/, $_, 2;
        $aliases->{$orig} = $alias;
    }
}

my $current = cwd;
for my $file (@ARGV) {
    $file = File::Spec->file_name_is_absolute($file) ? $file : "$current/$file";
    if (my $info = parse_info($file, $aliases)) {
        generate_link($info, $file);
    } else {
        warn "Can't get info from $file\n";
    }
}

sub parse_info {
    my $base = decode_utf8(basename(shift));
    my $aliases = shift || {};

    my $ext;
    $base =~ s/\.(\w+)$/$ext = $1; ""/e;

    $base =~ s/_/ /g;

    my @tags;
    if ($base =~ s/\s+(RAW)$//i) {
        push @tags, $1;
    }

    my %pair = ('[' => ']', '(', => ')', "\x{3010}" => "\x{3011}");
    my $tag_re = join "|", map { quotemeta($_) . "(.*?)" . quotemeta($pair{$_}) } keys %pair;

    while ($base =~ s/^(?:$tag_re)\s*|\s*(?:$tag_re)\.?$// ) {
        push @tags, split /\s+/, ($1 || $2 || $3 || $4 || $5 || $6);
    }

    if ($base =~ s/\.(HR|[HP]DTV|WS|AAC|AC3|DVDRip|PROPER|DVDSCR|720p|1080p|[hx]264(?:-\w+)?|dd51)\.(.*)//i) {
        my $tags = "$1.$2";
        $base =~ s/\./ /g;
        # ad-hoc: rescue DD.MM.YY(YY)
        $base =~ s/(\d\d) (\d\d) (\d\d(\d\d)?)\b/$1.$2.$3/;
        push @tags, split /\./, $tags;
    }

    if ($base =~ s/\s+(RAW)$//i) {
        push @tags, $1;
    }

    $base =~ s/\s*(end|finale)\s*$//i;

    for my $orig (keys %$aliases) {
        $base =~ s/^$orig/$aliases->{$orig}/
            and last;
    }

    my $info;
    if ($base =~ s/\s*EP?(\d+)\s*$//i) {
        $info->{episode} = $1 + 0;
    } elsif ($base =~ s/(?:\s+-)?\s+(\d+)\s*$//) {
        $info->{episode} = $1 + 0;
    } elsif ($base =~ s/\s*\x{7b2c}(\d+)(?:\x{8a71}|\x{56de})\s*$//) {
        $info->{episode} = $1 + 0;
    }

    if ($base =~ s/\s*(?:S(?:eason)?)?\s*(\d+)\d*$//) {
        $info->{season} = $1 + 0;
    }

    return unless $info->{episode};

    $info->{season} ||= 1;
    $info->{series} = $base;

    return $info;
}

sub generate_link {
    my($info, $file) = @_;

    my $ext = ($file =~ /\.(\w+)$/)[0];
    $info->{series} = normalize_series($info->{series});

    my $path = "$BaseDir/$info->{series}/Season $info->{season}";
    mkpath $path;

    my $link = sprintf "%s/%s - S%02dE%02d.%s", $path, $info->{series}, $info->{season}, $info->{episode}, $ext;
    symlink $file, $link;
}

sub normalize_series {
    my $name = shift;
    $name =~ s/^\s*|\s*$|-//g; # Plex doesn't like in series name apparently
    return $name;
}

sub selftest {
    eval "use Test::More";
    plan('no_plan');
    while (<DATA>) {
        my $info = parse_info($_, { "Name Show" => "Show Name" });
        is_deeply($info, {
            series => "Show Name",
            season => 1,
            episode => 6,
        });
    }
    exit;
}

__DATA__
