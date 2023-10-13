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

sub new(%)                                                                      # Create a new B Tree
 {my (%options) = @_;                                                           # Options
  my $n = genHash(__PACKAGE__,
    keys => $options{keys}//3,                                                  # Maximum number of keys a in block in this tree
    size => 0,                                                                  # Number of keys in tree
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

  my $R = $z->root;                                                             # Root exists
  if ($z->size < $z->keys)                                                      # Room in root
   {return $R->insert($k, $d);
   }

   if ($R->used == $z->keys)                                                  # Split root because no room left in root
    {my $l = $z->block;  my $r = $z->block;                                     # New left and right children
     while($R->index->@* > 1)                                                # Load left and right children
      {my $li = shift $R->index->@*;
       $l->insert($R->keys->[$li], $R->data->[$li]);
       my $ri = pop $R->index->@*;
       $r->insert($R->keys->[$ri], $R->data->[$ri]);
      }
     my $n = $z->block;                                                         # Move remaining key into position at start of new root
     my $i = $R->index->[0];
     $n->insert($R->keys->[$i], $R->data->[$i], next=>$l);
     $n->next->[1] = $r;
     $z->root = $n;                                                             # Replace existing root with new root
    }

  my $b = $z->root;                                                             # Root exists and has been split
  descend: for(my $i = 0;$i < 10 && defined($b); ++$i)                          # Step down through tree splitting full nodes to facilitate insertion
   {my $u = $b->used;
    my $l;                                                                      # First key in the block that is greater than the supplied key
    for(my $i = 0; $i < $u; ++$i)                                               # Search for key.  Inefficient in code because it is sequential, but in hardware this will be done in parallel
     {my $x = $b->index->[$i];                                                  # Indirection via index
      if ($b->keys->[$x] == $k)                                                 # Numeric comparison because strings can be constructed from numbers and fixed width numbers are easier to handle in hardware than varying length strings
       {  $b->data->[$x] =  $d;                                                 # Insert data at existing key
        return 1;                                                               # Successful insert by updating data associated  with key
       }
      if ($b->keys->[$x] > $k)                                                  # First existing key that is greater than the supplied key
       {$l = $i;
        my $B = $b->next->[$x];                                                 # Child node to descend to
        if (defined $B)                                                         # Not a leaf
         {if ($B->used == $z->keys)                                             # Split non leaf and delay descent
           {my $l = $z->block; my $r = $z->block;                               # New left and right children
            while($B->index->@* > 1)                                            # Load left and right children
             {my $L = shift $B->index->@*;
              $l->insert($B->keys->[$L], $B->data->[$L], next=>$B->next->[$L]);
              my $R = pop $B->index->@*;
              $r->insert($B->keys->[$R], $B->data->[$R], next=>$B->next->[$R]);
             }
            my $i = $B->index->[0];                                             # Remaining key is the one to split on
            $b->next->[$x] = $r;                                                # New right
            $b->insert($B->keys->[$i], $B->data->[$i], next=>$l);               # New left
           }
          else                                                                  # Descend immediately without splitting
           {$b = $B;
           }
         }
        next descend;                                                           # Either delaying descent after split or descending because no split required
       }
     }
    my $B = $b->next ? $b->next->[$b->index->[$u]] : undef;                     # Child node to descend to because given key is bigger than all existing keys
    if (defined $B)                                                             # Not a leaf so we can descend
     {$b = $B;
      next descend;                                                             # Descended off end of block
     }
    else
     {return $b->insert($k, $d);                                                # Leaf so insert directly knowing that there will be a room because this block would have been split earlier if it were full when we descended to it
     }
   }
  confess "Loop in B Tree";
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

  $z->size++;                                                                   # We can add the new key

  if (defined($l))                                                              # Insert into the block
   {my $n = splice $b->index->@*, $u, 1;                                        # Index value to move
    splice $b->index->@*, $l, 0, $n;                                            # Shift up
    $b->keys->[$n] = $k;                                                        # Insert key
    $b->data->[$n] = $d;                                                        # Insert data
    $b->next->[$n] = $options{next} if $options{next};                          # Insert next link
    $b->used++;
   }

  else                                                                          # Extend block
   {$b->keys->[$u] = $k;                                                        # Insert key
    $b->data->[$u] = $d;                                                        # Insert data
    $b->next->[$b->index->[$b->used]] = $options{next} if $options{next};       # Insert next link
    $b->used++;
   }
  $b
 }

unless(caller)                                                                  # Tests
 {eval "use Test::More qw(no_plan);";

  my $z = new();
  $z->insert(1, 101);
  $z->insert(3, 303);
  $z->insert(2, 202);
  is_deeply($z->root->index, [0, 2, 1]);

  $z->insert(8, 606);
  is_deeply($z->root->keys, [2]);
  is_deeply($z->root->next->[0]->keys, [1]);
  is_deeply($z->root->next->[1]->keys, [3,8]);

say STDERR "AAAA", dump($z);
  $z->insert(4, 404);
  is_deeply($z->root->keys, [2]);
  is_deeply($z->root->next->[0]->keys, [1]);
  is_deeply($z->root->next->[1]->keys, [3,4]);

  say STDERR "AAAA", dump($z);
 }
