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
use JSON;
use URI;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new;

my $section = shift or die "Usage: fix-plex-thumbnail [section ID]\n";
my $query = shift || "recentlyAdded";
my $plex_host = shift || "http://localhost:32400";

my %shows;
my $xml = $ua->get("$plex_host/library/sections/$section/$query")->content;
while ($xml =~ /<Video ratingKey="(\d+)" .*?grandparentRatingKey="(\d+)" .*?grandparentTitle="(.*?)"/g) {
    my $id = $1;
    my $show_id = $2;
    my $title = $3;

    update_episode_thumb($id);
    update_show_thumb($show_id, $title) unless $shows{$show_id}++;
}

sub update_episode_thumb {
    my $id = shift;

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
        if (@posters) {
            print "---> Changing poster of episode $id to $posters[0]\n";
            my $uri = URI->new("$plex_host/library/metadata/$id/poster");
            $uri->query_form(url => $posters[0]);
            my $res = $ua->put($uri);
            print "---> Thumbnail updated to: ", $res->content, "\n";
        } else {
            warn "Could not find alternate thumbnails for $id\n";
        }
    }
}

sub update_show_thumb {
    my($id, $title) = @_;

    my $xml = $ua->get("$plex_host/library/metadata/$id/posters")->content;
    if ($xml =~ /<Photo/) {
        return;
    }

    my $image_url = google_search($title) or return;

    print "---> Changing poster of show $id ($title) to $image_url\n";
    my $uri = URI->new("$plex_host/library/metadata/$id/posters");
    $uri->query_form(url => $image_url);
    my $res = $ua->post($uri);

    print "---> Thumbnail updated to: ", $res->content, "\n";
}

sub google_search {
    my $title = shift;

    my $uri = URI->new("https://www.googleapis.com/customsearch/v1");
    $uri->query_form('q' => $title, key => $ENV{GOOGLE_KEY}, cx => $ENV{GOOGLE_CX}, searchType => "image");

    my $res = $ua->get($uri);

    my $result = JSON::decode_json($res->content);
    return $result->{items}[0]{link};
}
