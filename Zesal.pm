#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/
#-------------------------------------------------------------------------------
# B-Tree implementation in a manner suitable for implementation in an FPGA.
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2023
#-------------------------------------------------------------------------------
use v5.34;
package Zesal;                                                                  # B Tree
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
eval "use Test::More qw(no_plan);" unless caller;

sub new(%)                                                                      # Create a new B Tree
 {my (%options) = @_;                                                           # Options
  my $n = genHash(__PACKAGE__,
    keys => $options{keys}//3,                                                  # Maximum number of keys a in block
    root => undef,                                                              # Root block
   );
 }

sub block($%)                                                                   # Create a new block in the B Tree
 {my ($z, %options) = @_;                                                       # Tree, options
  my $n = genHash("Zesal::Block",                                               # A block of (key, data,next) triples in a B Tree.
    index => [0..$z->keys-1],                                                   # Indirect references to (key, data, next) triples to reduce amount of data moved during insertions and deletions
    keys  => [],                                                                # Keys in block
    data  => [],                                                                # Data in block
    next  => undef,                                                             # References to blocks in the next lower level if there is one
    used  => 0,                                                                 # Number of (key,data,next) triples used so far
    tree  => $z,                                                                # Variable in software so we can explore a range of possibilities but permanently set in hardware to gain performance
   );
 }

sub insert($$$%)                                                                # Insert a new data, key pair in a tree
 {my ($z, $k, $d, %options) = @_;                                               # Tree, key, data
  if (!defined $z->root)                                                        # Empty tree
   {my $r = $z->root = $z->block();
    return $r->insert($k, $d);
   }
  my $r = $z->root;                                                             # Root exists
  if ($r->used < $z->keys)                                                      # Room in root
   {return $r->insert($k, $d);
   }
 }

sub Zesal::Block::insert($$$%)                                                  # Insert a new data, key pair
 {my ($b, $k, $d, %options) = @_;                                               # Tree, key, data
  my $z = $b->tree;
  my $u = $b->used;
  my $l;                                                                        # First key in the block that is greater than the supplied key
  for(my $i = 0; $i < $u; ++$i)                                                 # Search for key.  Inefficient in code because it is sequential, but in hardware this will be done in parallel
   {my $x = $b->index->[$i];                                                    # Indirection via index
    if ($b->keys->[$x] == $k)                                                   # Numeric comparison because strings can be constructed from numbers and fixed width numbers are easier to handle in hardware than varying length strings
     {$b->data->[$x] = $d;                                                      # Insert data at existing key
      return 1;                                                                 # Successful insert by updating data associated  with key
     }
    if ($b->keys->[$x] > $k)                                                    # First existing key that is greater than the supplied key
     {$l = $i; last;
     }
   }
  return 0 unless $u < $z->keys;                                                # No room to extend this block

  if (defined($l))                                                              # Insert into the block
   {my $n = splice $b->index->@*, $u, 1;                                        # Index value to move
    splice $b->index->@*, $l, 0, $n;                                            # Shift up
    $b->keys->[$n] = $k;                                                        # Insert key
    $b->data->[$n] = $d;                                                        # Insert data
    $b->used++;
   }

  else                                                                          # Extend block
   {$b->keys->[$u] = $k;                                                        # Insert key
    $b->data->[$u] = $d;                                                        # Insert data
    $b->used++;
   }
  $b
 }

my $z = new();
$z->insert(1, 101);
$z->insert(3, 303);
$z->insert(2, 202);

say STDERR "AAAA", dump($z);
