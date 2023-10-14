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

makeDieConfess;
my $debug;

sub reasonableDepth {9}                                                         # A reasonable maximum depth for a tree

my sub new(%)                                                                   # Create a new B Tree
 {my (%options) = @_;                                                           # Options
  my $n = genHash(__PACKAGE__,
    keys => $options{keys}//3,                                                  # Maximum number of keys a in block in this tree
    size => 0,                                                                  # Number of keys in tree
    root => undef,                                                              # Root block
    blocks => 0,                                                                # Sequence number to identify blocks in this tree
   );
 }

sub block($%)                                                                   # Create a new block in the B Tree
 {my ($z, %options) = @_;                                                       # Tree, options
  my $i = ++$z->blocks;                                                         # BLock number
  my $n = genHash("Zesal::Block",                                               # A block of (key, data,next) triples in a B Tree.
    index => [0..$z->keys-1],                                                   # Indirect references to (key, data, next) triples to reduce amount of data moved during insertions and deletions
    keys  => [],                                                                # Keys in block
    data  => [],                                                                # Data in block
    next  => undef,                                                             # References to blocks in the next lower level if there is one
    last  => undef,                                                             # The current last child block
    used  => 0,                                                                 # Number of (key,data,next) triples used so far
    tree  => $z,                                                                # Variable in software so we can explore a range of possibilities but permanently set in hardware to gain performance
    id    => $i,                                                                # Block number to help us identify it in dumps
   );
 }

#D1 Insert                                                                      # Constrict a tree by inserting keys and data

sub splitNode($$)                                                               # Split a child node into two nodes and insert them into the parent block assuming that there will be enough space available.
 {my ($z, $B) = @_;                                                             # Tree, parent, child
  my $l = $z->block; my $r = $z->block;                                         # New left and right children
  while($B->index->@* > 1)                                                      # Load left and right children
   {my $li = shift $B->index->@*;
    my $ri = pop   $B->index->@*;
    $l->insert($B->keys->[$li], $B->data->[$li], $B->next ? (next => $B->next->[$li]) : ());
    $r->insert($B->keys->[$ri], $B->data->[$ri], $B->next ? (next => $B->next->[$ri]) : ());
   }
   my $i = $B->index->[0];                                                      # Remaining key is the one to split on
   $l->last = $B->next->[$i]; $r->last = $B->last;

  ($l, $r, $i)
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

   $R->used <= $z->keys or confess "Number used has got too big";               # Check that the number used is plausible

   if ($R->used == $z->keys)                                                    # Split root because no room left in root
    {my ($l, $r, $i) = $z->splitNode($R);                                       # New left and right children
     my $n = $z->block;                                                         # Move remaining key into position at start of new root
     $n->insert($R->keys->[$i], $R->data->[$i], next=>$l, at=>0);
     $n->last = $r;
     $z->root = $n;                                                             # Replace existing root with new root
    }

  my $b = $z->root;                                                             # Root exists and has been split
  descend: for(my $j = 0; $j < reasonableDepth() && defined($b); ++$j)          # Step down through tree splitting full nodes to facilitate insertion
   {my $u = $b->used;
    my $l;                                                                      # First key in the block that is greater than the supplied key

#if ($debug)
# {say STDERR "AAAA j=$j k = $k";
#  say STDERR $z->printFlat;
#  $z->printTree;
#  say STDERR "BBBB end";
# }
    for(my $i = 0; $i < $u; ++$i)                                               # Search for key.  Inefficient in code because it is sequential, but in hardware this will be done in parallel
     {my $x = $b->index->[$i];                                                  # Indirection via index
      if ($b->keys->[$x] == $k)                                                 # Numeric comparison because strings can be constructed from numbers and fixed width numbers are easier to handle in hardware than varying length strings
       {  $b->data->[$x] =  $d;                                                 # Insert data at existing key
        return 1;                                                               # Successful insert by updating data associated  with key
       }
      if ($b->keys->[$x] > $k)                                                  # First existing key that is greater than the supplied key
       {my $B = $b->next ? $b->next->[$x] : undef;                              # Child node to descend to
        if (defined $B)                                                         # Not a leaf
         {if ($B->used == $z->keys)                                             # Split child if full and delay descent
           {my ($l, $r, $b0) = $z->splitNode($B);                               # New left and right children
            $b->next->[$x] = $r;                                                # New right
            $b->insert($B->keys->[$b0], $B->data->[$b0], next=>$l, at=>$i);     # New left
           }
          else                                                                  # Descend immediately without splitting
           {$b = $B;
           }
          next descend;                                                         # Either delaying descent after split or descending because no split required
         }
        else                                                                    # On a leaf and the key is not present on the leaf
         {$b->insert($k, $d);
          return;
         }
       }
     }

    my $B = $b->last;                                                           # Child node to descend to because given key is bigger than all existing keys
    if (defined $B)                                                             # Not a leaf so we can descend
     {if ($B->used == $z->keys)                                                 # Split child at end if full and delay descent
       {my ($l, $r, $i) = $z->splitNode($B);                                    # New left and right children
        $b->insert($B->keys->[$i], $B->data->[$i], next=>$l, at=>$b->used);     # New left
        $b->last = $r;                                                          # New right is last child
       }
      else                                                                      # Descend immediately as no split was required
       {$b = $B;
       }
      next descend;                                                             # Descended off end of block
     }
    else
     {return $b->insert($k, $d);                                                # Leaf so insert directly knowing that there will be a room because this block would have been split earlier if it were full when we descended to it
     }
   }
  $z->printTree(title=>"Loop in tree");
  confess;
 }
# 2023-10-14 Added at=> option to located the new child in the parent.
sub Zesal::Block::insert($$$%)                                                  # Insert a new data, key pair
 {my ($b, $k, $d, %options) = @_;                                               # Tree, key, data

  my $z = $b->tree;
  my $u = $b->used;
  confess "No room in block" unless $u < $z->keys;                              # No room to extend this block

  my $l = $options{at};                                                         # First key in the block that is greater than the supplied key
  if (!defined($l))                                                             # Find the insertion location in the parent if it has not been supplied
   {for(my $i = 0; $i < $u; ++$i)                                               # Search for key.  Inefficient in code because it is sequential, but in hardware this will be done in parallel
     {my $x = $b->index->[$i];                                                  # Indirection via index
      if ($b->keys->[$x] == $k)                                                 # Numeric comparison because strings can be constructed from numbers and fixed width numbers are easier to handle in hardware than varying length strings
       {$b->data->[$x] = $d;                                                    # Insert data at existing key
        return 1;                                                               # Successful insert by updating data associated  with key
       }
      if ($b->keys->[$x] > $k)                                                  # First existing key that is greater than the supplied key
       {$l = $i; last;
       }
     }
   }

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

#D1 Find                                                                        # Find the data associated with a key in a B-Tree

sub find($$%)                                                                   # Find the data associated with a key in a B-Tree
 {my ($z, $k, %options) = @_;                                                   # Key to find, options
  return undef unless my $p = $z->root;                                         # Root node or nothing

  find: for(my $j = 0; $j < reasonableDepth() && defined($p); ++$j)             # Step down through tree
   {my $u = $p->used;
    for(my $i = 0; $i < $u; ++$i)                                               # Search for key.  Inefficient in code because it is sequential, but in hardware this will be done in parallel
     {my $x = $p->index->[$i];                                                  # Indirection via index
      my $K = $p->keys->[$x];                                                   # Key
      return $p->data->[$x] if $K == $k;                                        # Numeric comparison because strings can be constructed from numbers and fixed width numbers are easier to handle in hardware than varying length strings
      if ($K > $k)                                                              # First existing key that is greater than the supplied key
       {if (my $n = $p->next)                                                   # Step down
         {$p = $p->next->[$x];
          next find;
         }
        else                                                                    # Leaf so we cannot find the ley
         {return undef;
         }
       }
     }
    if (my $n = $p->last)                                                       # Bigger than any key in the block
     {$p = $n;
      next find;
     }
    else                                                                        # Leaf so we cannot find the ley
     {return undef;
     }
   };
  confess "Find looping";
 }

#D1 Iterate                                                                     # Traverse the tree

sub iterate($%)                                                                 # All [key, data] pairs as an array in ascending key order
 {my ($z, %options) = @_;                                                       # Object, options

  my @z;                                                                        # Keys: [key, depth]

  my sub p($)                                                                   # Unpack a block
   {my ($b) = @_;                                                               # Block, depth
    if ($b->next)                                                               # Not a leaf
     {for(my $i = 0; $i < $b->used; ++$i)                                       # Locate elements in ascending order noting the depth of each one
       {my $x = $b->index->[$i];
        __SUB__->($b->next->[$x]);
        push @z, [$b->keys->[$x], $b->data->[$x]];
       }
      __SUB__->($b->last);
     }
    else                                                                        # Leaf
     {for(my $i = 0; $i < $b->used; ++$i)                                       # Locate elements in ascending order noting the depth of each one
       {my $x = $b->index->[$i];
        push @z, [$b->keys->[$x], $b->data->[$x],];
       }
     }
   }
  p($z->root);
  @z
 }

#D1 Print                                                                       # Print a B Tree and its components

sub Zesal::Block::print($%)                                                     # Print a block
 {my ($b, %options) = @_;                                                       # Block, options
  my @k; my @d; my @n;
  for(my $i = 0; $i < $b->used; ++$i)                                           # Locate elements in ascending order noting the depth of each one
   {if (defined(my $x = $b->index->[$i]))
     {push @k, $b->keys->[$x];
      push @d, $b->data->[$x];
      push @n, $b->next->[$x] if $b->next;
     }
    else
     {my $id = $b->id;
      confess "Invalid index $i in block: $id ".dump($b->index);
     }
   }
  my $k = pad join(' ', map{sprintf "%4d", $_    } @k), 32;
  my $d = pad join(' ', map{sprintf "%4d", $_    } @d), 32;
  my $n = pad join(' ', map{sprintf "%4d", $_->id} @n), 32;
  my $i = $b->id;
  my $u = $b->used;
  my $U = ''; $U = '*' if @k != $u;
  my $l = $b->last ? $b->last->id : '';
  my $t = '    '.($options{title}//'');
  my $D = '    ' x ($options{indent}//0);
  say STDERR <<END;
${D}Block: $i   Keys: $k   Next: $n   Last: $l  used=$u$U     $t
END
 }

sub printTree($%)                                                               # Print a tree
 {my ($z, %options) = @_;                                                       #
  my @k;                                                                        # Keys: [key, depth]
  my $print; $print = sub                                                       # Print a block
   {my ($b, $d) = @_;                                                           # Block, depth
    $b->print(indent=>$d);
    if ($b->next)                                                               # Not a leaf
     {for(my $i = 0; $i < $b->used; ++$i)                                       # Locate elements in ascending order noting the depth of each one
       {my $x = $b->index->[$i];
        $print->($b->next->[$x], $d+1);
       }
      $print->($b->last, $d+1);
     }
   };
  my $title = ' '.($options{title}//'');
  if (my $r = $z->root)
   {say STDERR "Tree$title" ;
    $print->($r, 0);
   }
  else
   {say STDERR "Tree is empty" ;
   }
 }

sub printFlat($%)                                                               # Print a tree horizontally
 {my ($z, %options) = @_;                                                       #
  my @k;                                                                        # Keys: [key, depth]

  my sub p($$)                                                                  # Print a block
   {my ($b, $d) = @_;                                                           # Block, depth
    if ($b->next)                                                               # Not a leaf
     {for(my $i = 0; $i < $b->used; ++$i)                                       # Locate elements in ascending order noting the depth of each one
       {my $x = $b->index->[$i];
        __SUB__->($b->next->[$x], $d+1);
        push @k, [$b->keys->[$x], $d];
       }
      __SUB__->($b->last, $d+1);
     }
    else                                                                        # Leaf
     {for(my $i = 0; $i < $b->used; ++$i)                                       # Locate elements in ascending order noting the depth of each one
       {my $x = $b->index->[$i];
        push @k, [$b->keys->[$x], $d];
       }
     }
   };

  return "" unless my $r = $z->root;                                            # Empty tree

  p($r, 1);                                                                     # Order keys with their depths

  my $L = max(map{length($$_[0])} @k);                                          # Maximum width of a key
  my $D = max(map{       $$_[1] } @k);                                          # Maximum depth of a key

  my @p;                                                                        # Layout tree horizontally
  for my $depth(1..$D)                                                          # Each line of output with lowest levels first to put the root at the top
   {my @l;
    for my $i(keys @k)                                                          # Each key at this level
     {my ($k, $d) = $k[$i]->@*;
      if ($d == $depth)                                                         # Keys at this depth
       {push @l, sprintf "%${L}d", $k;
       }
      else
       {push @l, " " x $L;
       }
     }
    push @p, join(' ', @l) =~ s(\s+\Z) ()r;
   }
  join "\n", @p, '';
 }

#D0 Tests                                                                       # Tests and examples

eval {return 1} unless caller;
eval "use Test::More qw(no_plan);";
eval "Test::More->builder->output('/dev/null');" if -e q(/home/phil/);

if (1)
 {my $z = new();
  $z->insert(1, 101);
  $z->insert(3, 303);
  $z->insert(2, 202);
  is_deeply($z->root->index, [0, 2, 1]);

  $z->insert(8, 808);
  is_deeply($z->root->keys, [2]);
  is_deeply($z->root->next->[0]->keys, [1]);
  is_deeply($z->root->last->keys,      [3,8]);

  $z->insert(5, 505);
  is_deeply($z->root->keys, [2]);
  is_deeply($z->root->next->[0]->keys, [1]);
  is_deeply($z->root->last->keys,  [3,8,5]);
  is_deeply($z->root->last->index, [0, 2, 1]);

  $z->insert(4, 404);
  is_deeply($z->root->keys, [2,5]);
  is_deeply($z->root->next->[0]->keys, [1]);
  is_deeply($z->root->next->[1]->keys, [3,4]);
  is_deeply($z->root->last->keys,      [8]);

  is_deeply($z->printFlat, <<END);
  2     5
1   3 4   8
END

  $z->insert(6, 606);
  is_deeply($z->printFlat, <<END);
  2     5
1   3 4   6 8
END

  $z->insert(7, 707);
  is_deeply($z->printFlat, <<END);
  2     5
1   3 4   6 7 8
END

  $z->insert(9, 909);
  is_deeply($z->printFlat, <<END);
  2     5   7
1   3 4   6   8 9
END

  $z->insert(10, 10010);
  is_deeply($z->printFlat, <<END);
             5
    2              7
 1     3  4     6     8  9 10
END

  $z->insert(20, 20020);
  is_deeply($z->printFlat, <<END);
             5
    2              7     9
 1     3  4     6     8    10 20
END

  $z->insert($_, $_."0".$_) for 21..23;
  is_deeply($z->printFlat, <<END);
             5           9
    2              7          20
 1     3  4     6     8    10    21 22 23
END

  $z->insert($_, $_."0".$_) for 11..13;
  is_deeply($z->printFlat, <<END);
             5           9
    2              7          11       20
 1     3  4     6     8    10    12 13    21 22 23
END

  $z->insert($_, $_."0".$_) for reverse 14..19;
  is_deeply($z->printFlat, <<END);
                         9
             5                      13
    2              7          11             16    18    20
 1     3  4     6     8    10    12    14 15    17    19    21 22 23
END
 }

if (0)                                                                          # Randomize an array
 {my @r = 1..100;
  for my $i(keys @r)
   {my $a = rand(@r); my $A = $r[$a];
    my $b = rand(@r); my $B = $r[$b];
    $r[$b] = $A; $r[$a] = $B;
   }
  my $r = join ', ', @r;
  say qq(my \@r = ($r););
  exit;
 }

if (1)                                                                          # Random load
 {my @r = (51, 69, 3, 4, 5, 62, 7, 88, 18, 40, 14, 91, 60, 24, 15, 86, 64, 16, 56, 31, 98, 47, 58, 36, 84, 10, 22, 53, 100, 79, 2, 32, 59, 25, 94, 70, 38, 63, 75, 9, 42, 20, 99, 41, 80, 26, 95, 73, 54, 1, 76, 43, 77, 92, 13, 49, 57, 23, 74, 96, 71, 50, 87, 21, 65, 66, 67, 28, 30, 81, 93, 34, 37, 55, 44, 83, 68, 78, 52, 45, 61, 17, 35, 27, 85, 82, 11, 48, 89, 90, 46, 19, 12, 8, 6, 39, 97, 72, 29, 33);
  my $z = new();
  $z->insert($_, $_) for @r;
  #say STDERR $z->printFlat;
  is_deeply($z->printFlat, <<END);
                                                                                                                                                                                                         51
                                                                     18                                                  31                                                                                                                                  64                                                          79
                          7                      13                                          24                                                                      42                                                              58                                          69                                                                          88                      94
              4                      10                  15                          22              26      28                      34      36              40              44          47                          54                              62              66                          73      75                      81          84                              92                      98
  1   2   3       5   6       8   9      11  12      14      16  17      19  20  21      23      25      27      29  30      32  33      35      37  38  39      41      43      45  46      48  49  50      52  53      55  56  57      59  60  61      63      65      67  68      70  71  72      74      76  77  78      80      82  83      85  86  87      89  90  91      93      95  96  97      99 100
END

  is_deeply($z->find($_), $_) for @r;
  ok(!$z->find($_)) for 0, 1+@r;

  is_deeply([$z->iterate], [map{[$_, $_]} 1..100]);
 }

if (1)                                                                          # Reverse load
 {my $z = new();
  $z->insert($_, $_) for reverse 1..64;
  #say STDERR $z->printFlat;
  is_deeply($z->printFlat, <<END);
                                                                                                33                                              49
                                                17                      25                                              41                                              57
                         9          13                      21                      29                      37                      45                      53                      61
       3     5     7          11          15          19          23          27          31          35          39          43          47          51          55          59          63
 1  2     4     6     8    10    12    14    16    18    20    22    24    26    28    30    32    34    36    38    40    42    44    46    48    50    52    54    56    58    60    62    64
END
 }

if (1)                                                                          # Sequential load
 {my $z = new();
  $z->insert($_, $_) for 1..64;
  #say STDERR $z->printFlat;
  is_deeply($z->printFlat, <<END);
                                             16                                              32
                      8                                              24                                              40                      48
          4                      12                      20                      28                      36                      44                      52          56
    2           6          10          14          18          22          26          30          34          38          42          46          50          54          58    60    62
 1     3     5     7     9    11    13    15    17    19    21    23    25    27    29    31    33    35    37    39    41    43    45    47    49    51    53    55    57    59    61    63 64
END
 }
