#!/usr/bin/perl
# rnd_ebooks.pl -- tweets a random text snippet from a collection of pdf files
# This program is free software licensed under GPL version 2
use strict;
use Regexp::Common qw(URI);
use Config::Tiny;
use Net::Twitter;
use Encode;

# source directory with pdf files
my $pdf_dir = "$ENV{HOME}/path_to_pdf_files";

#-----------------------------------------

# read config file
my $config = Config::Tiny->read("$ENV{HOME}/.rnd-ebooks")
    or die("error reading config: " . Config::Tiny->errstr . "\n");

sub cfg_read { $config->{connect_params}->{$_[0]} or die("invalid config: missing $_[0]\n"); }

my $consumer_key = cfg_read('consumer_key');
my $consumer_secret = cfg_read('consumer_secret');
my $access_token_key = cfg_read('access_token_key');
my $access_token_secret = cfg_read('access_token_secret');

# pick a random pdf file
my @pdf_list = glob "$pdf_dir/*.pdf";
my $pdf_selected = $pdf_list[int(rand($#pdf_list+1))];
print "selected file: $pdf_selected\n";

# get page count
my $page_count = (split ' ', `pdfinfo "$pdf_selected" | grep Pages`)[1];

# select a random page
my $sel_page = int(rand($page_count)) + 1;
print "selected page: $sel_page / $page_count\n";

# extract raw text from pdf file
my @lines = split "\n", decode('utf8', `pdftotext -f $sel_page -l $sel_page "$pdf_selected" - 2> /dev/null`);

sub trim { $_[0] =~ s/^\s+//; $_[0] =~ s/\s+$//; $_[0]; }

# pick a random line from text
my $line_selected;
my $i = 0;
do
{
    $line_selected = trim($lines[int(rand($#lines+1))]);
    if ($line_selected =~ m/$RE{URI}{HTTP}/) { ++$i; next; }    # skip lines with URL's (to prevent spam)
    die("couldn't find a line") if (++$i > 100);                # file might have no text (image-only pdf)
} while (length($line_selected) < 3);
print "selected line: $line_selected\n";

# remove last word until if fits 140 characters
while (length($line_selected) > 140)
{
    $line_selected =~ s/[^\s\.,;:]+$//;
}

die("trying to tweet empty line") if (length($line_selected) == 0);
print "   final line: $line_selected\n";

# tweet it
my $api = Net::Twitter->new(
    traits => [qw/OAuth API::REST/],
    consumer_key => $consumer_key,
    consumer_secret => $consumer_secret,
    access_token => $access_token_key,
    access_token_secret => $access_token_secret,
);
$api->update($line_selected);
