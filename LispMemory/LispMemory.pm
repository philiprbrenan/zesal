#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/
#-------------------------------------------------------------------------------
# Lisp memory
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2024
#-------------------------------------------------------------------------------
# Free String, garabage collection
use v5.34;
package Lisp::Memory;
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);

makeDieConfess;

#D1 Construct                                                                   # Construct lisp memory

sub new(%)                                                                      # Create a new lisp memory
 {my (%options) = @_;                                                           # Options
  genHash(__PACKAGE__,                                                          # Lisp memeory
    map   => {},                                                                # Maps a key to a value
    lisps => 0,                                                                 # Number of lisp pairs
   );
 }

sub newLisp($%)                                                                 # Create a new lisp memory pair. Pairs allow us to fanout quickly to create a structure of any size
 {my ($memory, %options) = @_;                                                  # Memory, options
  sprintf "l%08d", ++$memory->lisps                                             # The next pair available
 }

sub wrap($$%)                                                                   # Create a new user value
 {my ($memory, $value, %options) = @_;                                          # Memory, user value, options
  sprintf "u%08d", $value                                                       # User value
 }

sub put($$$%)                                                                   # Map a key to a value
 {my ($memory, $key, $value, %options) = @_;                                    # Memory, key, value, options
  $memory->isUserOrLisp($key);
  $memory->isUserOrLisp($value);
  $memory->map->{$key} = $value
 }

sub get($$%)                                                                    # Get the value of a key in a lisp memory
 {my ($memory, $key, %options) = @_;                                            # Memory, key, options
  $memory->isUserOrLisp($key);
  $memory->map->{$key}
 }

sub unwrap($$%)                                                                 # Unwrap a value returned from memory to retrieve its original value
 {my ($memory, $value, %options) = @_;                                          # Memory, value, options
  $memory->isUserOrLisp($value);
  substr($value, 1)+0
 }

sub join($$$%)                                                                  # Join two values to make a lisp pair
 {my ($memory, $a, $b, %options) = @_;                                          # Memory, first value, second value, key, options
  $memory->isUserOrLisp($_, butNotPair=>1) for ($a, $b);
  "$a $b"
 }

sub split($$%)                                                                  # Split a lisp pair into two separate values
 {my ($memory, $value, %options) = @_;                                          # Memory, lisp pair, options
  my ($a, $b) = split / /, $value;
  $memory->isUserOrLisp($_) for ($a, $b);
  ($a, $b)
 }

sub getUser($$%)                                                                # Get a value expected to be a user value and return it as such.
 {my ($memory, $key, %options) = @_;                                            # Memory, key, options
  my $v = $memory->map->{$key};
  defined($v) or confess <<"END" =~ s/\n(.)/ $1/gsr;
No value for key: $key
END
  $memory->isUser($v) or confess <<"END" =~ s/\n(.)/ $1/gsr;
The value for key $key is not a user value
END
  substr($v, 1)+0
 }

sub isUser($$%)                                                                 # Test whether a value is a user value
 {my ($memory, $key, %options) = @_;                                            # Memory, key, options
  $key =~ m(\Au\d*\Z)
 }

sub isLisp($$%)                                                                 # Test whether a value is a user value
 {my ($memory, $key, %options) = @_;                                            # Memory, key, options
  $key =~ m(\Al\d*\Z)
 }

sub isPair($$%)                                                                 # Test whether a value is a pair of values
 {my ($memory, $key, %options) = @_;                                            # Memory, key, options
  $key =~ m( )                                                                  # Pair
 }

sub isUserOrLisp($$%)                                                           # Test whether a value is a user or lisp value
 {my ($memory, $key, %options) = @_;                                            # Memory, key, options
  my $m = $memory;
  if (!defined($options{butNotPair}) and $m->isPair($key))                                                         # Pair
   {my @p = $m->split($key);
    return $m->isUserOrLisp($p[0]) && $m->isUserOrLisp($p[1]);
   }
  return 1 if $m->isUser($key);
  return 2 if $m->isLisp($key);
  confess <<"END" =~ s/\n(.)/ $1/gsr;
Not a user or lisp value: $key
END
 }

sub null($%)                                                                    # The lisp null value
 {my ($memory, %options) = @_;                                                  # Memory, options
  q(l)
 }

sub isNull($$%)                                                                 # Test whether a value is a lisp null value
 {my ($memory, $value, %options) = @_;                                          # Memory, value, options
  $value =~ m(\Al\Z)
 }

#D1 Data Structures                                                             # Standard data structures constructed in lisp memory

#D2 Strings                                                                     # Strings constructed from string memory

sub newString($$%)                                                              # Create a string using lisp memory
 {my ($memory, $string, %options) = @_;                                         # Memory, string, options
  my $m = $memory;
  my @c = split //, $string;
  my @l = map {$m->newLisp()} @c;
  push @l, $m->null;
  for my $i(keys @c)
   {my $p = $m->join($m->wrap(ord($c[$i])), $l[$i+1]);
    $m->put($l[$i], $p);
   }
  $l[0]
 }

sub getString($$%)                                                              # Return the characters in a string
 {my ($memory, $string, %options) = @_;                                         # Memory, string, options
  my $L = $options{first};
  my $m = $memory;
  return undef unless defined(my $s = $m->get($string));                        # Look up the string
  my $C = '';
  for(;$s;)                                                                     # Step along the characters of the string
   {my ($c, $n) = $m->split($s);
    $C .=  chr($m->unwrap($c));
    last if $m->isNull($n);
    $s = $m->get($n);
    last if defined($L) and length($C) >= $L;
   }
  $C
 }

#D2 Fixed Arrays                                                                # Create fixed length arrays.  The lengths of these arrays is a power of two.

sub newArray($$%)                                                               # Create a string using lisp memory
 {my ($memory, $length, %options) = @_;                                         # Memory, length of array, options
  my $m = $memory;
  my @l;
  for my $i(1..$length)
   {push @l, my $k = $m->newLisp;
    $m->put($k, $m->null);
   }

  while(@l > 1)
   {my @L;
    while(@l > 1)
     {my $a = shift @l; my $b = shift @l;
      my $v = $m->join($a, $b);
      push @L, my $k = $m->newLisp;
      $m->put($k, $v);
     }
    if (@l)
     {my $a = shift @l; my $b = $m->null;
      my $v = $m->join($a, $b);
      push @L, my $k = $m->newLisp;
      $m->put($k, $v);
     }
    @l = @L;
   }
  @l ? $l[0] : $m->null
 }

sub getArray($$$%)                                                              # Return the value of an indexed element of the array
 {my ($memory, $array, $index, %options) = @_;                                  # Memory, array, index, options
  my $L = $options{first};
  my $m = $memory;
  return undef unless defined(my $s = $m->get($array));                         # Look up the string
  my $C = '';
  for(;$s;)                                                                     # Step along the characters of the string
   {my ($c, $n) = $m->split($s);
    $C .=  chr($m->unwrap($c));
    last if $m->isNull($n);
    $s = $m->get($n);
    last if defined($L) and length($C) >= $L;
   }
  $C
 }


#D0

=pod

=encoding utf-8

=head1 Name

LispMemory - Manage Memory in the Manner of Lisp

=head1 Synopsis

=head1 Description

Manage Memory in the Manner of Lisp


The following sections describe the methods in each functional area of this
module.  For an alphabetic listing of all methods by name see L<Index|/Index>.



=head1 Construct

Construct lisp memory

=head2 newÂ (%options)

Create a new lisp memory

     Parameter  Description
  1  %options   Options

B<Example:>


  #latest:;


=head2 newLispÂ ($memory, %options)

Create a new lisp memory pair. Pairs allow us to fanout quickly to create a structure of any size

     Parameter  Description
  1  $memory    Memory
  2  %options   Options

B<Example:>


  if (1)
   {my $m = new;

    my $l = $m->newLisp;  # ððð®ðºð½ð¹ð²

    my $a = $m->wrap(1);
    my $b = $m->wrap(2);
    my $p = $m->join($a, $b);
            $m->put ($l, $p);
    my $P = $m->get ($l);
    my ($A, $B) = $m->split($P);
    is_deeply($A, $a);
    is_deeply($B, $b);
    is_deeply($m->unwrap($A), 1);
    is_deeply($m->unwrap($B), 2);
    ok $m->isLisp($l);
    ok $m->isUserOrLisp($l);
   }


=head2 wrap($memory, $value, %options)

Create a new user value

     Parameter  Description
  1  $memory    Memory
  2  $value     User value
  3  %options   Options

B<Example:>


  if (1)
   {my $m = new;
    my $l = $m->newLisp;

    my $a = $m->wrap(1);  # ððð®ðºð½ð¹ð²


    my $b = $m->wrap(2);  # ððð®ðºð½ð¹ð²

    my $p = $m->join($a, $b);
            $m->put ($l, $p);
    my $P = $m->get ($l);
    my ($A, $B) = $m->split($P);
    is_deeply($A, $a);
    is_deeply($B, $b);
    is_deeply($m->unwrap($A), 1);
    is_deeply($m->unwrap($B), 2);
    ok $m->isLisp($l);
    ok $m->isUserOrLisp($l);
   }


=head2 putÂ ($memory, $key, $value, %options)

Map a key to a value

     Parameter  Description
  1  $memory    Memory
  2  $key       Key
  3  $value     Value
  4  %options   Options

B<Example:>


  #latest:;


=head2 getÂ ($memory, $key, %options)

Get the value of a key in a lisp memory

     Parameter  Description
  1  $memory    Memory
  2  $key       Key
  3  %options   Options

B<Example:>


  #latest:;


=head2 unwrapÂ Â ($memory, $value, %options)

Unwrap a value returned from memory to retrieve its original value

     Parameter  Description
  1  $memory    Memory
  2  $value     Value
  3  %options   Options

B<Example:>


  if (1)
   {my $m = new;
    my $l = $m->newLisp;
    my $a = $m->wrap(1);
    my $b = $m->wrap(2);
    my $p = $m->join($a, $b);
            $m->put ($l, $p);
    my $P = $m->get ($l);
    my ($A, $B) = $m->split($P);
    is_deeply($A, $a);
    is_deeply($B, $b);

    is_deeply($m->unwrap($A), 1);  # ððð®ðºð½ð¹ð²


    is_deeply($m->unwrap($B), 2);  # ððð®ðºð½ð¹ð²

    ok $m->isLisp($l);
    ok $m->isUserOrLisp($l);
   }


=head2 join($memory, $a, $b, %options)

Join two values to make a lisp pair

     Parameter  Description
  1  $memory    Memory
  2  $a         First value
  3  $b         Second value
  4  %options   Key

B<Example:>


  if (1)
   {my $m = new;
    my $l = $m->newLisp;
    my $a = $m->wrap(1);
    my $b = $m->wrap(2);

    my $p = $m->join($a, $b);  # ððð®ðºð½ð¹ð²

            $m->put ($l, $p);
    my $P = $m->get ($l);
    my ($A, $B) = $m->split($P);
    is_deeply($A, $a);
    is_deeply($B, $b);
    is_deeply($m->unwrap($A), 1);
    is_deeply($m->unwrap($B), 2);
    ok $m->isLisp($l);
    ok $m->isUserOrLisp($l);
   }


=head2 splitÂ Â Â ($memory, $value, %options)

Split a lisp pair into two separate values

     Parameter  Description
  1  $memory    Memory
  2  $value     Lisp pair
  3  %options   Options

B<Example:>


  if (1)
   {my $m = new;
    my $l = $m->newLisp;
    my $a = $m->wrap(1);
    my $b = $m->wrap(2);
    my $p = $m->join($a, $b);
            $m->put ($l, $p);
    my $P = $m->get ($l);

    my ($A, $B) = $m->split($P);  # ððð®ðºð½ð¹ð²

    is_deeply($A, $a);
    is_deeply($B, $b);
    is_deeply($m->unwrap($A), 1);
    is_deeply($m->unwrap($B), 2);
    ok $m->isLisp($l);
    ok $m->isUserOrLisp($l);
   }


=head2 getUserÂ ($memory, $key, %options)

Get a value expected to be a user value and return it as such.

     Parameter  Description
  1  $memory    Memory
  2  $key       Key
  3  %options   Options

B<Example:>


  #latest:;


=head2 isUserÂ Â ($memory, $key, %options)

Test whether a value is a user value

     Parameter  Description
  1  $memory    Memory
  2  $key       Key
  3  %options   Options

B<Example:>


  #latest:;


=head2 isLispÂ Â ($memory, $key, %options)

Test whether a value is a user value

     Parameter  Description
  1  $memory    Memory
  2  $key       Key
  3  %options   Options

B<Example:>


  if (1)
   {my $m = new;
    my $l = $m->newLisp;
    my $a = $m->wrap(1);
    my $b = $m->wrap(2);
    my $p = $m->join($a, $b);
            $m->put ($l, $p);
    my $P = $m->get ($l);
    my ($A, $B) = $m->split($P);
    is_deeply($A, $a);
    is_deeply($B, $b);
    is_deeply($m->unwrap($A), 1);
    is_deeply($m->unwrap($B), 2);

    ok $m->isLisp($l);  # ððð®ðºð½ð¹ð²

    ok $m->isUserOrLisp($l);
   }


=head2 isPairÂ Â ($memory, $key, %options)

Test whether a value is a pair of values

     Parameter  Description
  1  $memory    Memory
  2  $key       Key
  3  %options   Options

=head2 isUserOrLisp($memory, $key, %options)

Test whether a value is a user or lisp value

     Parameter  Description
  1  $memory    Memory
  2  $key       Key
  3  %options   Options

B<Example:>


  if (1)
   {my $m = new;
    my $l = $m->newLisp;
    my $a = $m->wrap(1);
    my $b = $m->wrap(2);
    my $p = $m->join($a, $b);
            $m->put ($l, $p);
    my $P = $m->get ($l);
    my ($A, $B) = $m->split($P);
    is_deeply($A, $a);
    is_deeply($B, $b);
    is_deeply($m->unwrap($A), 1);
    is_deeply($m->unwrap($B), 2);
    ok $m->isLisp($l);

    ok $m->isUserOrLisp($l);  # ððð®ðºð½ð¹ð²

   }


=head2 null($memory, %options)

The lisp null value

     Parameter  Description
  1  $memory    Memory
  2  %options   Options

B<Example:>


  #latest:;


=head2 isNullÂ Â ($memory, $value, %options)

Test whether a value is a lisp null value

     Parameter  Description
  1  $memory    Memory
  2  $value     Value
  3  %options   Options

B<Example:>


  #latest:;


=head1 Data Structures

Standard data structures constructed in lisp memory

=head2 Strings

Strings constructed from string memory

=head3 newStringÂ Â Â ($memory, $string, %options)

Create a string using lisp memory

     Parameter  Description
  1  $memory    Memory
  2  $string    String
  3  %options   Options

B<Example:>


  if (1)
   {my $m = new;

    my $s = $m->newString("Hello World");  # ððð®ðºð½ð¹ð²

    is_deeply($s, "l00000001");
    is_deeply($m, {lisps => 11, map => {
      l00000001 => "u00000072 l00000002",
      l00000002 => "u00000101 l00000003",
      l00000003 => "u00000108 l00000004",
      l00000004 => "u00000108 l00000005",
      l00000005 => "u00000111 l00000006",
      l00000006 => "u00000032 l00000007",
      l00000007 => "u00000087 l00000008",
      l00000008 => "u00000111 l00000009",
      l00000009 => "u00000114 l00000010",
      l00000010 => "u00000108 l00000011",
      l00000011 => "u00000100 l",
    }});
    is_deeply($m->getString($s),           "Hello World");
    is_deeply($m->getString($s, first=>5), "Hello");
   }


=head3 getStringÂ Â Â ($memory, $string, %options)

Return the characters in a string

     Parameter  Description
  1  $memory    Memory
  2  $string    String
  3  %options   Options

=head2 Fixed Arrays

Create fixed length arrays.  The lengths of these arrays is a power of two.

=head3 newArray($memory, $length, %options)

Create a string using lisp memory

     Parameter  Description
  1  $memory    Memory
  2  $length    Length of array
  3  %options   Options

B<Example:>


  if (1)
   {my $m = new;

    my $s = $m->newArray(3);  # ððð®ðºð½ð¹ð²

    is_deeply($s, "l00000006");
    is_deeply($m, {lisps => 6, map => {
      l00000001 => "l",
      l00000002 => "l",
      l00000003 => "l",
      l00000004 => "l00000001 l00000002",
      l00000005 => "l00000003 l",
      l00000006 => "l00000004 l00000005",
     }})
   }


=head3 getArray($memory, $array, $index, %options)

Return the value of an indexed element of the array

     Parameter  Description
  1  $memory    Memory
  2  $array     Array
  3  $index     Index
  4  %options   Options


=head1 Hash Definitions




=head2 Lisp::Memory Definition


Lisp memeory




=head3 Output fields


=head4 lisps

Number of lisp pairs

=head4 map

Maps a key to a value



=head1 Index


1 L<get|/get> - Get the value of a key in a lisp memory

2 L<getArray|/getArray> - Return the value of an indexed element of the array

3 L<getString|/getString> - Return the characters in a string

4 L<getUser|/getUser> - Get a value expected to be a user value and return it as such.

5 L<isLisp|/isLisp> - Test whether a value is a user value

6 L<isNull|/isNull> - Test whether a value is a lisp null value

7 L<isPair|/isPair> - Test whether a value is a pair of values

8 L<isUser|/isUser> - Test whether a value is a user value

9 L<isUserOrLisp|/isUserOrLisp> - Test whether a value is a user or lisp value

10 L<join|/join> - Join two values to make a lisp pair

11 L<new|/new> - Create a new lisp memory

12 L<newArray|/newArray> - Create a string using lisp memory

13 L<newLisp|/newLisp> - Create a new lisp memory pair.

14 L<newString|/newString> - Create a string using lisp memory

15 L<null|/null> - The lisp null value

16 L<put|/put> - Map a key to a value

17 L<split|/split> - Split a lisp pair into two separate values

18 L<unwrap|/unwrap> - Unwrap a value returned from memory to retrieve its original value

19 L<wrap|/wrap> - Create a new user value

=head1 Installation

This module is written in 100% Pure Perl and, thus, it is easy to read,
comprehend, use, modify and install via B<cpan>:

  sudo cpan install Lisp::Memory

=head1 Author

L<philiprbrenan@gmail.com|mailto:philiprbrenan@gmail.com>

L<http://prb.appaapps.com|http://prb.appaapps.com>

=head1 Copyright

Copyright (c) 2016-2023 Philip R Brenan.

This module is free software. It may be used, redistributed and/or modified
under the same terms as Perl itself.

=cut



goto finish if caller;
clearFolder(q(out), 99);                                                        # Clear the output folder
my $start = time;
eval "use Test::More";
eval "Test::More->builder->output('/dev/null')" if -e q(/home/phil/);
eval {goto latest} if -e q(/home/phil/);

my sub  ok($) {!$_[0] and confess; &ok( $_[0])}
my sub nok($) {&ok(!$_[0])}

# Tests

#latest:;                                                                       #Tnull #TisNull
if (1)
 {my $m = new;
  my $a = $m->null;
  ok $m->isNull($a);
 }

#latest:;                                                                       #Tnew #Tput #Tget #TisUser #TgetUser
if (1)
 {my $m = new;
  my $a = $m->wrap(1);
  my $b = $m->wrap(2);
          $m->put($a, $b);
  my $v = $m->get($a);
  is_deeply($v,            "u00000002");
  is_deeply($m->isUser($v),  1);
  is_deeply($m->getUser($a), 2);
 }

#latest:;
if (1)                                                                          #TnewLisp #TisLisp #TisUserOrLisp #Twrap #Tunwrap #Tjoin #Tsplit
 {my $m = new;
  my $l = $m->newLisp;
  my $a = $m->wrap(1);
  my $b = $m->wrap(2);
  my $p = $m->join($a, $b);
          $m->put ($l, $p);
  my $P = $m->get ($l);
  my ($A, $B) = $m->split($P);
  is_deeply($A, $a);
  is_deeply($B, $b);
  is_deeply($m->unwrap($A), 1);
  is_deeply($m->unwrap($B), 2);
  ok $m->isLisp($l);
  ok $m->isUserOrLisp($l);
 }

#latest:;
if (1)                                                                          #TnewString #TgetString
 {my $m = new;
  my $s = $m->newString("Hello World");
  is_deeply($s, "l00000001");
  is_deeply($m, {lisps => 11, map => {
    l00000001 => "u00000072 l00000002",
    l00000002 => "u00000101 l00000003",
    l00000003 => "u00000108 l00000004",
    l00000004 => "u00000108 l00000005",
    l00000005 => "u00000111 l00000006",
    l00000006 => "u00000032 l00000007",
    l00000007 => "u00000087 l00000008",
    l00000008 => "u00000111 l00000009",
    l00000009 => "u00000114 l00000010",
    l00000010 => "u00000108 l00000011",
    l00000011 => "u00000100 l",
  }});
  is_deeply($m->getString($s),           "Hello World");
  is_deeply($m->getString($s, first=>5), "Hello");
 }

#latest:;
if (1)                                                                          #TnewArray
 {my $m = new;
  my $s = $m->newArray(3);
  is_deeply($s, "l00000006");
  is_deeply($m, {lisps => 6, map => {
    l00000001 => "l",
    l00000002 => "l",
    l00000003 => "l",
    l00000004 => "l00000001 l00000002",
    l00000005 => "l00000003 l",
    l00000006 => "l00000004 l00000005",
   }})
 }

&done_testing;
finish: 1
