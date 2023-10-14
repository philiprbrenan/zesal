# Zesal #

We use an extreme [version](https://en.wikipedia.org/wiki/Software_versioning)
of the [B-Tree](https://en.wikipedia.org/wiki/B-tree) algorithm in a
form suitable for implementation on an [fpga](https://en.wikipedia.org/wiki/Field-programmable_gate_array)
or as a doc on a chip. Each node of the [B-Tree](https://en.wikipedia.org/wiki/B-tree)
has perhaps 1M entries. Such the binary [tree](https://en.wikipedia.org/wiki/Tree_(data_structure))
would need only two levels to hold 10^12 objects.

Within each object we have one level of indirection between an index [array](https://en.wikipedia.org/wiki/Dynamic_array)
that holds the indices of the key/data/node triples in ascending order.
The index is considerably smaller than the key/data/node triples and so
is easier to perform shift up by one, shift down by one, search for
equals and search for smallest just bigger than a key.

# Interactions with each node #

Typical interactions are to query the node for a key/data/node triple
or to add a new key/data/node triple or to delete one. Performing these
actions requires efficient implementations of the following operations

## Find a key equal to the key being sought ##

The equality checks are performed in parallel to create an equals mask
which can be reduced to a binary number in log(n) time where n is the
number of [bit](https://en.wikipedia.org/wiki/Bit)s required to address
all the keys in the node.

## Find smallest key greater than the key being sought ##

We produce a greater than mask. As the index orders the keys in
ascending order there will mask will start with 0s and end in 1s unless
of course they are all 0 or are all 1. We can check each pair in
parallel to produce a mask that can be reduced to a binary number of in
O(n) time.

# Algorithms #

The following operations can be performed in parallel in Time(1) at the
cost of a large number of gates

## Number to mask ##

Each [bit](https://en.wikipedia.org/wiki/Bit) of the mask has an AND
gate that selects the [bit](https://en.wikipedia.org/wiki/Bit)s from
the number needed to decide whether the mask [bit](https://en.wikipedia.org/wiki/Bit)
should be on or off. Time(1)

## Mask to number ##

Each [bit](https://en.wikipedia.org/wiki/Bit) of the number has an OR
gate that selects the [bit](https://en.wikipedia.org/wiki/Bit)s in the
mask that enables that [bit](https://en.wikipedia.org/wiki/Bit).
Time(1) although it does rely on rather wide OR gates .

## Monotone mask to break point number ##

Use an AND gate that has for input each sequential pair of [bit](https://en.wikipedia.org/wiki/Bit)s,
the lwoer one inverted to detect the boundary. Then use Mask to number
to get the corresponding number in Time(1).

## Break point number to monotone mask ##

Each mask [bit](https://en.wikipedia.org/wiki/Bit) knows its own number
which it compares to the break point number. If the number of the mask
[bit](https://en.wikipedia.org/wiki/Bit) is equal or greater than the
break point number the corresponding mask [bit](https://en.wikipedia.org/wiki/Bit)
is set in Time(1).

## Shift an [array](https://en.wikipedia.org/wiki/Dynamic_array) by one
from a specified index ##

With a monotone mask we can shift an [array](https://en.wikipedia.org/wiki/Dynamic_array)
up or down one from a specified index int Time(1). First copy the [array](https://en.wikipedia.org/wiki/Dynamic_array)
to a buffer and set a monotone mask indicating the locations that are
to be shifted. Then copy back the copied elements into their new
positions as indicated by the mask.
