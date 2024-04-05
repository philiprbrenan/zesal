#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/ -I/home/phil/perl/cpan/SiliconChipWiring/lib/
#-------------------------------------------------------------------------------
# Test wire drawing using GDS2
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2024
#-------------------------------------------------------------------------------
use v5.34;
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use Silicon::Chip::Wiring;
use Test::More;
use GDS2;
use utf8;

makeDieConfess;

my $wireWidth = 1/4;

my $c = Silicon::Chip::Wiring::new(width=>10, height=>16);
ok $c->wire(x=>1, y=>5,  X=>3, Y=>7,  d=>0, l=>1); # AAAx
ok $c->wire(x=>1, y=>3,  X=>3, Y=>1,  d=>0, l=>1); # BBBx
ok $c->wire(x=>7, y=>5,  X=>5, Y=>7,  d=>0, l=>1); # CCCx
ok $c->wire(x=>7, y=>3,  X=>5, Y=>1,  d=>0, l=>1); # DDDx

ok $c->wire(x=>1, y=>13, X=>3, Y=>15, d=>1, l=>1); # EEEx
ok $c->wire(x=>1, y=>11, X=>3, Y=>9,  d=>1, l=>1); # GGG
ok $c->wire(x=>7, y=>11, X=>5, Y=>9,  d=>1, l=>1); # HHH
ok $c->wire(x=>7, y=>13, X=>5, Y=>15, d=>1, l=>1); # GGG

my $g = new GDS2(-fileName=>'>test.gds');                                       # Vias between layers to transmit wiring on each level down to the gate level
$g->printInitLib(-name=>'test');
$g->printBgnstr (-name=>'test');

my $s  = $wireWidth/2;                                                          # Half width of the wore
my $s1 = 1/2 + $s;                                                              # Center of wire
my $s2 = $wireWidth; # 2 * $s                                                   # Width of wire

for my $l(0..3)                                                                 # Insulation, x layer, insulation, y layer
 {for   my $x(0..$c->width)                                                     # Gate io pins run vertically
   {for my $y(0..$c->height)
     {my $x1 = $x; my $y1 = $y;
      my $x2 = $x1 + $wireWidth; my $y2 = $y1 + $wireWidth;
      $g->printBoundary(-layer=>$l, -xy=>[$x1,$y1, $x2,$y1, $x2,$y2, $x1,$y2]); # Via
      $g->printText    (-layer=>$l, -xy=>[$x1,$y1+$wireWidth*1.2], -string=>"$x1,$y1", -font=>3); # Coordinates string
     }
   }
 }

my @w  = $c->wires->@*;                                                         # Wires

for my $w(@w)                                                                   # Layout each wire
 {my ($x, $y, $X, $Y, $d, $L) = @$w{qw(x y X Y d l)};

  if ($d == 0)                                                                  # X first
   {$g->printPath(-layer=>1, -width=>$s2, -xy=>[                                # Along x
      $x+$s,      $y+$s2,
      $x+$s,      $y+$s1,
      $X+1-$s2,   $y+$s1]);
    $g->printBoundary(-layer=>2, -xy=>[                                         # Up one level
      $X+1/2,     $y+1/2,
      $X+1/2+$s2, $y+1/2,
      $X+1/2+$s2, $y+1/2+$s2,
      $X+1/2,     $y+1/2+$s2]);                                                 # Along y
    $g->printPath(-layer=>3, -width=>$s2, -xy=>[
      $X+1/2+$s,  $y+1/2+$s2,
      $X+1/2+$s,  $Y+$s,
      $X,         $Y+$s]);
   }
  else                                                                          # Y first
   {$g->printPath(-layer=>1, -width=>$s2, -xy=>[                                # Along x
      $X+$s,      $Y+$s2,
      $X+$s,      $Y+$s1,
      $x+1-$s2,   $Y+$s1]);
    $g->printBoundary(-layer=>2, -xy=>[                                         # Up one level
      $x+1/2,     $Y+1/2+$s2,
      $x+1/2+$s2, $Y+1/2+$s2,
      $x+1/2+$s2, $Y+1/2,
      $x+1/2,     $Y+1/2,
      ]);
    $g->printPath(-layer=>3, -width=>$s2, -xy=>[                                # Along y
      $x+$s,      $y+$s,
      $x+1/2+$s,  $y+$s,
      $x+1/2+$s,  $Y+1/2+$s2,
      ]);
   }
 }

$g->printEndstr;
$g->printEndlib();
