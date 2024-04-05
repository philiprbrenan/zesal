#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/
#-------------------------------------------------------------------------------
# Push Pitch deck to GitHub
# Philip R Brenan at gmail dot com, Appa Apps Ltd Inc., 2023
#-------------------------------------------------------------------------------
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use GitHub::Crud qw(:all);
use feature qw(say current_sub);
# prb.appaapps.com/zesal/pitchdeck/pitchDeck.html
makeDieConfess;

my $home   = q(/home/phil/zesal/pitchDeck/);                                    # Local files
my $user   = q(philiprbrenan);                                                  # User
my $repo   = q(philiprbrenan.github.io);                                        # Repo
my $folder = q(zesal/pitchdeck);                                                # Project in philiprbrenan.github.io
my $pd     = q(pitchDeck);                                                      # Pitch deck file
my $html   = fpe $home, $pd, q(htm);                                            # Input html  file
my $wf     = q(.github/workflows/main.yml);                                     # Work flow on Ubuntu
my $diagrams = [
q(/home/phil/perl/cpan/SiliconChipBtree/lib/Silicon/Chip/svg/tree.svg),
q(/home/phil/perl/cpan/SiliconChipBtree/lib/Silicon/Chip/svg/tree_1.svg)
];

expandWellKnownWordsAsUrlsAndAddTocToMakeANewHtmlFile $html;                    # Upgrade html

for my $i(@$diagrams)                                                           # Create png fropm svg as they load faster when displayed in a browser
 {my $j = fpe $home, q(images), fn($i), q(png);
  say STDERR qx(inkscape -w 4096 -o $j -b "none" $i) unless -e $j;
  my $k = fpe $home, q(images), fn($i)."2", q(png);
  say STDERR qx(convert $j -alpha set -channel A -evaluate set 10%  $k)  unless -e $k;
 }

push my @f, searchDirectoryTreesForMatchingFiles($home, qw(.html .png .pptx));  # Files to upload
for my $s(@f)                                                                   # Upload each selected file
 {next unless $s =~ m(pitchDeck.html|pitchDeck.pptx|logo.png|tree2?.png|tree_1.png|BTreeOnGDS2.png);
  next unless $s =~ m(pitchDeck.html|pitchDeck.pptx);
  next if $s =~ m(/z/);
  my $c = readBinaryFile($s);                                                   # Load file
  my $t = fpf $folder, swapFilePrefix $s, $home;
  my $w = writeFileUsingSavedToken($user, $repo, $t, $c);
  lll "$w $s $t";
 }
