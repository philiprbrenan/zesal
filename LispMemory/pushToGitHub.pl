#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/
#-------------------------------------------------------------------------------
# Push LispMemory code to GitHub
# Philip R Brenan at gmail dot com, Appa Apps Ltd Inc., 2024
#-------------------------------------------------------------------------------
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use GitHub::Crud qw(:all);
use Pod::Markdown;
use feature qw(say current_sub);

makeDieConfess;

my $home = q(/home/phil/zesal/LispMemory/);                                     # Local files
my $user = q(philiprbrenan);                                                    # User
my $repo = q(LispMemory);                                                       # Repo
my $wf   = q(.github/workflows/main.yml);                                       # Work flow on Ubuntu

sub pod($$)                                                                     # Write pod file
 {my ($in, $out) = @_;                                                          # Input, output file
  updateDocumentation readFile $in;
  my $d = expandWellKnownUrlsInPerlFormat extractPodDocumentation $in;
  my $p = Pod::Markdown->new;
  my $m;
     $p->output_string(\$m);
     $p->parse_string_document("=pod\n\n$d\n\n=cut\n");                         # Create Pod and convert to markdown
     $m =~ s(POD ERRORS.*\Z) ();
     owf($out, $m);                                                             # Write markdown
 }

if (1)                                                                          # Documentation from pod to markdown into read me with well known words expanded
 {pod fpf($home, q(LispMemory.pm)), fpf($home, q(README.md));

  push my @files, searchDirectoryTreesForMatchingFiles($home,                   # Files
    qw(.md .pl .pm .svg));

  for my $s(@files)                                                             # Upload each selected file
   {my $c = readFile($s);                                                       # Load file
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

    - name: Install Tree
      run:
        sudo apt install tree

    - name: Tree
      run:
        tree

    - name: Cpan
      run:  sudo cpan install -T Data::Dump

    - name: Test Lisp Memory
      run:
        perl -Idtt/lib LispMemory.pm
END

  my $f = writeFileUsingSavedToken $user, $repo, $wf, $y;                       # Upload workflow
  lll "Ubuntu work flow for $repo written to: $f";
 }
