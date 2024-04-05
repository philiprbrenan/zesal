#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/
#-------------------------------------------------------------------------------
# Push Zesal code to GitHub
# Philip R Brenan at gmail dot com, Appa Apps Ltd Inc., 2023
#-------------------------------------------------------------------------------
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use GitHub::Crud qw(:all);
use HTML::FormatMarkdown;
use feature qw(say current_sub);

my $string = HTML::FormatMarkdown->format_file(
    'test.html'
);

open my $fh, ">", "test.md" or die "$!\n";
print $fh $string;
close $fh;

makeDieConfess;

my $home      = q(/home/phil/zesal/);                                           # Local files
my $user      = q(philiprbrenan);                                               # User
my $repo      = q(zesal);                                                       # Repo
my $wf        = q(.github/workflows/main.yml);                                  # Work flow on Ubuntu

if (1)
 {my $m = HTML::FormatMarkdown->format_file(     q(README.html));               # README as html to markdown
  my $f = writeFileUsingSavedToken $user, $repo, q(README.md), $m;              # Upload markdown
 }

if (1)                                                                          # Upload files
 {#push my @files, searchDirectoryTreesForMatchingFiles($home, qw(.sv .tb .pm .pl));  # Files to upload
  push my @files, searchDirectoryTreesForMatchingFiles($home, qw(.gds .pl .pm .png)); # Files to upload
  for my $s(@files)                                                             # Upload each selected file
   {say STDERR $s;
    my $c = readBinaryFile($s);                                                 # Load file
    my $t = swapFilePrefix $s, $home;
    my $w = writeFileUsingSavedToken($user, $repo, $t, $c);
    lll "$w $s $t";
   }
 }

if (1)
 {my $d = dateTimeStamp;
  my $y = <<"END";
# Test $d

name: Test

on:
  push

jobs:

  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout\@v3
      with:
        ref: 'main'

    - uses: actions/checkout\@v3
      with:
        repository: philiprbrenan/DataTableText
        path: dtt

    - uses: actions/checkout\@v3
      with:
        repository: philiprbrenan/SvgSimple
        path: svg

    - name: Install Tree
      run:
        sudo apt install tree

    - name: Tree
      run:
        tree

    - name: Cpan
      run:  sudo cpan install -T Data::Dump
    - name: Ubuntu update
      run:  sudo apt update


    - name: Verilog installation
      run:  sudo apt -y install iverilog

    - name: Test Perl implementation of B Tree
      run:
        perl -Idtt/lib Zesal.pm

    - name: Test Perl implemented integrated circuits
      run:
        perl -Idtt/lib -Isvg/lib  Chip.pm

    - name: Test Verilog
      run:
        rm -f Zesal; iverilog -Iincludes/ -g2012 -o Zesal Zesal.sv Zesal.tb && timeout 1m ./Zesal
END

  my $f = writeFileUsingSavedToken $user, $repo, $wf, $y;                       # Upload workflow
  lll "Ubuntu work flow for $repo written to: $f";
 }
