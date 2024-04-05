#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/ -I/home/phil/perl/cpan/GitHubCrud/lib/
#-------------------------------------------------------------------------------
# Push Winter Holiday to github
# Philip R Brenan at gmail dot com, Appa Apps Ltd Inc., 2023
#-------------------------------------------------------------------------------
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use GitHub::Crud qw(:all);
use Pod::Markdown;
use feature qw(say current_sub);
use utf8;

makeDieConfess;

my $home   = q(/home/phil/zesal/logisim/CascadingAndComparator/);               # Local files
my $user   = q(philiprbrenan);                                                  # User
my $repo   = q(Comparator);                                                     # Repo
my @files = searchDirectoryTreesForMatchingFiles $home, qw(.png .circ .txt);    # Files

for my $s(@files)                                                               # Upload each selected file
 {my $c = readBinaryFile $s;                                                    # Load non html file
  my $t = fne $s;                                                               # Github name
  my $w = writeFileUsingSavedToken($user, $repo, $t, $c);                       # Upload
  lll "$w $s $t";
 }
