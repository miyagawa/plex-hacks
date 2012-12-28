#!/usr/bin/env perl
# Script to swap EyeTV generated MP4 thumbnail with Plex generated one

use strict;
use URI;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new;

my $section = shift or die "Usage: fix-plex-thumbnail [section ID]\n";
my $plex_host = shift || "http://localhost:32400";

my $xml = $ua->get("$plex_host/library/sections/10/recentlyAdded")->content;
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
        warn "---> Changing poster of $id to $posters[0]\n";
        my $uri = URI->new("$plex_host/library/metadata/$id/poster");
        $uri->query_form(url => $posters[0]);
        my $res = $ua->put($uri);
        warn $res->content;
    }
}
