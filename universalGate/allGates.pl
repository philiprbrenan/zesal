#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/
#-------------------------------------------------------------------------------
# All boolean gates
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2024
#-------------------------------------------------------------------------------
use v5.34;
package Lisp::Memory;
use warnings FATAL => qw(all);
use strict;
use Carp qw(confess cluck);
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);

makeDieConfess;

my %gates;
my %syns;

sub gate($$)                                                                    # Create a new gate
 {my ($sub, $name) = @_;                                                        # Expression, name
  my $s = (&$sub(0,0)? '1' : '0').
          (&$sub(0,1)? '1' : '0').
          (&$sub(1,0)? '1' : '0').
          (&$sub(1,1)? '1' : '0');
#!$gates{$s} or cluck "$name already exists as: ".$gates{$s};
  $gates{$s} = $name unless $gates{$s};
  $syns{$s}{$name}++;
 }

my $and0   = sub { $_[0] and  $_[1]};          gate $and0,   q(and0);  # 0001
my $and1   = sub {!$_[0] and  $_[1]};          gate $and1,   q(and1);  # 0100
my $and2   = sub { $_[0] and !$_[1]};          gate $and2,   q(and2);  # 0010
my $and3   = sub {!$_[0] and !$_[1]};          gate $and3,   q(and3);  # 1000

my $and0_1 = sub { $_[1] and 1};             gate $and0_1,   q(and0_1); # 0101
my $and1_1 = sub {!$_[1] and 1};             gate $and1_1,   q(and1_1); # 1010
my $and2_1 = sub { $_[1] and 1};             gate $and2_1,   q(and2_1);
my $and3_1 = sub {!$_[1] and 1};             gate $and3_1,   q(and3_1);

my $and0_0 = sub { $_[1] and 0};             gate $and0_0,   q(and0_0);  # 0000
my $and1_0 = sub {!$_[1] and 0};             gate $and1_0,   q(and1_0);
my $and2_0 = sub { $_[1] and 0};             gate $and2_0,   q(and2_0);
my $and3_0 = sub {!$_[1] and 0};             gate $and3_0,   q(and3_0);

my $and0__1   = sub { $_[0] and 1};             gate $and0__1,   q(and0__1);    # 0011
my $and1__1   = sub {!$_[0] and 1};             gate $and1__1,   q(and1__1);    # 1100
my $and2__1   = sub { $_[0] and 1};             gate $and2__1,   q(and2__1);
my $and3__1   = sub {!$_[0] and 1};             gate $and3__1,   q(and3__1);

my $and0__0   = sub { $_[0] and 0};             gate $and0__0,   q(and0__0);
my $and1__0   = sub {!$_[0] and 0};             gate $and1__0,   q(and1__0);
my $and2__0   = sub { $_[0] and 0};             gate $and2__0,   q(and2__0);
my $and3__0   = sub {!$_[0] and 0};             gate $and3__0,   q(and3__0);

my $nand0  = sub {!( $_[0] and  $_[1])};       gate $nand0,  q(nand0); # 1110
my $nand1  = sub {!(!$_[0] and  $_[1])};       gate $nand1,  q(nand1); # 1011
my $nand2  = sub {!( $_[0] and !$_[1])};       gate $nand2,  q(nand2); # 1101
my $nand3  = sub {!(!$_[0] and !$_[1])};       gate $nand3,  q(nand3); # 0111

my $nand0_1 = sub {!( $_[0] and 0)};            gate $nand0_1,   q(nand0_1); # 1111
my $nand1_1 = sub {!(!$_[0] and 0)};            gate $nand1_1,   q(nand1_1);

my $andOr   = sub {$_[0] && $_[1]  or !$_[0] && !$_[1]}; gate $andOr,   q(andOr); # Bad 1001

my $or0   = sub { $_[0] or   $_[1]};           gate $or0,    q(or0);
my $or1   = sub {!$_[0] or   $_[1]};           gate $or1,    q(or1);
my $or2   = sub { $_[0] or  !$_[1]};           gate $or2,    q(or2);
my $or3   = sub {!$_[0] or  !$_[1]};           gate $or3,    q(or3);

my $nor0   = sub {!( $_[0] or   $_[1])};       gate $nor0,   q(nor0);
my $nor1   = sub {!(!$_[0] or   $_[1])};       gate $nor1,   q(nor1);
my $nor2   = sub {!( $_[0] or  !$_[1])};       gate $nor2,   q(nor2);
my $nor3   = sub {!(!$_[0] or  !$_[1])};       gate $nor3,   q(nor3);

my $xor0  = sub { $_[0] xor   $_[1]};          gate $xor0,   q(xor0); # BAD 0110
my $xor1  = sub {!$_[0] xor   $_[1]};          gate $xor1,   q(xor1);
my $xor2  = sub { $_[0] xor  !$_[1]};          gate $xor2,   q(xor2);
my $xor3  = sub {!$_[0] xor  !$_[1]};          gate $xor3,   q(xor3);

my $nxor0  = sub {!( $_[0] xor   $_[1])};      gate $nxor0,  q(nxor0);
my $nxor1  = sub {!(!$_[0] xor   $_[1])};      gate $nxor1,  q(nxor1);
my $nxor2  = sub {!( $_[0] xor  !$_[1])};      gate $nxor2,  q(nxor2);
my $nxor3  = sub {!(!$_[0] xor  !$_[1])};      gate $nxor3,  q(nxor3);

my $eq  = sub { $_[0] == $_[1]};                gate $eq,   q(eq);
my $ne  = sub { $_[0] != $_[1]};                gate $ne,   q(ne);
my $le  = sub { $_[0] <= $_[1]};                gate $le,   q(le);
my $lt  = sub { $_[0] <  $_[1]};                gate $lt,   q(lt);
my $ge  = sub { $_[0] >= $_[1]};                gate $ge,   q(ge);
my $gt  = sub { $_[0] >  $_[1]};                gate $gt,   q(gt);

my $one       = sub { 1 };                        gate $one,       q(one);
my $zero      = sub { 0 };                        gate $zero,      q(zero);
my $continue1 = sub { $_[0] };                    gate $continue1, q(continue1);
my $negate1   = sub {!$_[0] };                    gate $negate1,   q(negate1);
my $continue2 = sub { $_[1] };                    gate $continue2, q(continue2);
my $negate2   = sub {!$_[1] };                    gate $negate2,   q(negate2);

my $onlyIf  = sub {  !$_[1] or $_[0]};             gate $onlyIf, q(onlyIf);
my $onlyIf1 = sub {!(!$_[1] or $_[0])};            gate $onlyIf1, q(onlyIf1);
my $iff     = sub {  !$_[0] || $_[1] and !$_[1] || $_[0]}; gate $iff, q(iff);
my $iff1   = sub {!(!$_[0] || $_[1] and !$_[1] || $_[0])}; gate $iff1, q(iff1);

say STDERR "Types: ", (scalar keys %gates);
say STDERR dump(\%gates);
say STDERR dump(\%syns);
