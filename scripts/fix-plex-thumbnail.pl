#!/usr/bin/env perl
# Script to swap EyeTV generated MP4 thumbnail with Plex generated one
#
# EyeTV generates its own thumbnail embedded in exported MP4 files for
# iTunes Home Sharing, which is great, but there are several issues:
# a) thumbnails have the title and EyeTV logo embedded and b) screen
# capture is from 0s, which usually shows the commercials from the
# previous show.
#
# This script tries to address that by replacing the thumbnail with
# Plex's own thumbnail by using Plex's HTTP API. You need perl 5.8 or
# later with LWP module installed.

use strict;
use URI;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new;

my $section = shift or die "Usage: fix-plex-thumbnail [section ID]\n";
my $plex_host = shift || "http://localhost:32400";

my $xml = $ua->get("$plex_host/library/sections/$section/recentlyAdded")->content;
while ($xml =~ /<Video ratingKey="(\d+)"/g) {
    my $id = $1;
    my $xml = $ua->get("$plex_host/library/metadata/$id/posters")->content;

    my(@posters, $selected);
    while ($xml =~ /<Photo.*ratingKey="(.*?)".*selected="(\d+)"/g) {
        if ($2) {
            $selected = $1;
        } else {
            push @posters, $1;
        }
    }

    if ($selected =~ /^metadata:/) {
        print "---> Changing poster of $id to $posters[0]\n";
        if (@posters) {
            my $uri = URI->new("$plex_host/library/metadata/$id/poster");
            $uri->query_form(url => $posters[0]);
            my $res = $ua->put($uri);
            print "---> Thumbnail changed to: ", $res->content, "\n";
        } else {
            warn "Could not find alternate thumbnails for $id\n";
        }
    }
}
