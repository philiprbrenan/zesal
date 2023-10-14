#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/
#-------------------------------------------------------------------------------
# Design a combinatorial set of gates with no loops
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2023
#-------------------------------------------------------------------------------
use v5.30;
package Icd::Designer;
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);

my %gates;                                                                      # Gates by output name

sub start()                                                                     # Start a circuit design
 {%gates = ();
 }

sub gate($$@)                                                                   # A gate of some sort defined by its single output name
 {my ($type, $output, @inputs) = @_;                                            # Gate type, output name, input names

  $gates{$output} and confess "Gate $output has already been specified";

  my $possibleTypes = q(and|input|nand|nor|not|or|output|xor);                  # Possible gate types
  $type =~ m(\A($possibleTypes)\Z)i or confess "Invalid gate type: $type, possible types are: $possibleTypes";

  my $g = genHash("Icd::Designer::Gate",                                        # Gate
   type   => $type,                                                             # Gate type
   output => $output,                                                           # Output name
   inputs => {map {$_=>1} @inputs},                                             # Input names
  );
  $gates{$output} = $g                                                          # Record gate and return it
 }

sub checkInputs(%)                                                              # Check that all inputs to all gates have been specified
 {my (%options) = @_;                                                           # Options

  for my $G(sort keys %gates)
   {my $g = $gates{$G};                                                         # Address gate
    for my $i(sort keys $g->inputs->%*)
     {return $i unless defined $gates{$i};
     }
   }
  undef                                                                         # No undefined inputs
 }

sub checkOutputs(%)                                                             # Check that all outputs are used
 {my (%options) = @_;                                                           # Options

  my %i; my %o;
  for my $G(sort keys %gates)                                                   # Find all inputs and outputs
   {my $g = $gates{$G};                                                         # Address gate
    $i{$_}++ for keys $g->inputs->%*;                                           # All inputs
    $o{$g->output}++ unless $g->type =~ m(output)i;                             # Outputs unless on an output gate
   }

  for my $o(sort keys %o)                                                       # Check that each output is used as an input
   {return $o unless $i{$o};                                                    # Check output becomes an input
   }
  undef                                                                         # No unused outputs
 }

sub simulate($%)                                                                # Simulate the set of gates until nothing changes.  This should be possible as feedback loops are banned.
 {my ($inputs, %options) = @_;                                                  # Hash of input names to values, options

  if (1)                                                                        # Check all inputs are defined
   {my $m = checkInputs;
    confess "Missing input $m" if $m;
   }

  if (1)                                                                        # Check all outputs are used
   {my $m = checkOutputs;
    confess "Unused output $m" if $m;
   }

  my %values  = %$inputs;                                                       # The current set of values

  my $t; for($t = 0; $t < 100; ++$t)                                            # Steps in time
   {my $c = 0;                                                                  # Changes made
    for my $G(sort keys %gates)
     {my $g = $gates{$G};                                                       # Address gate
      if ($g->type =~ m(\Aand\Z)i)                                              # Elaborate an AND gate
       {my $f = 0;
        for my $i(sort keys $g->inputs->%*)
         {++$f unless exists $values{$i} and $values{$i};
         }
        my $r = $f ? 0 : 1;                                                     # Resulting output
        $c++ unless defined($values{$g->output}) and $values{$g->output} == $r; # Check for change in current output
        $values{$g->output} = $r;                                               # Update state of circuit
       }
     }
    last unless $c;                                                             # Keep going until nothing changes
   }

  return genHash("Idc::Designer::Simulation::Results",
                   # Simulation results
    steps  => $t,                                                               # Number of steps to achieve no change anywhere
    values => \%values,                                                         # Values of every output at point of stability
   );
 }

#D0 Tests                                                                       # Tests and examples

eval {return 1} unless caller;
eval "use Test::More qw(no_plan);";
eval "Test::More->builder->output('/dev/null');" if -e q(/home/phil2/);
eval {goto latest};

if (1)                                                                          # Unused output
 {start;
  gate("input",  "i1");
  eval {simulate({i1=>1})};
  ok($@ =~ m(Unused output i1)i);
 }

if (1)                                                                          # Gate already specified
 {start;
  my $i1 = gate("input",  "i1");
  eval    {gate("input",  "i1")};
  ok($@ =~ m(Gate i1 has already been specified));
 }

if (1)                                                                          # Check all inputs
 {start;
  my $i1 = gate("input",  "i1");
  my $i2 = gate("input",  "i2");
  my $a  = gate("and",    "and1", qw(i1 i2));
  my $o  = gate("output", "o", "an1");
  eval {simulate({i1=>1, i2=>1})};
  ok($@ =~ m(Missing input an1)i);
 }

if (1)                                                                          # Check all inputs
 {start;
  my $i1 = gate("input",  "i1");
  my $i2 = gate("input",  "i2");
  my $a  = gate("and",    "and1", qw(i1 i2));
  my $o  = gate("output", "o", "an1");
  eval {simulate({i1=>1, i2=>1})};
  ok($@ =~ m(Missing input an1)i);
 }

if (1)                                                                          # Single and gate
 {start;
  my $i1 = gate("input",  "i1");
  my $i2 = gate("input",  "i2");
  my $a  = gate("and",    "and1", qw(i1 i2));
  my $o  = gate("output", "o", "and1");
  my $s  = simulate({i1=>1, i2=>1});
  ok($s->steps          == 1);
  ok($s->values->{and1} == 1);
 }

#latest:;
if (1)                                                                          # Single and gate
 {start;
  my $i11 = gate("input",  "i11");
  my $i12 = gate("input",  "i12");
  my $a1  = gate("and",    "and1", qw(i11 i12));
  my $i21 = gate("input",  "i21");
  my $i22 = gate("input",  "i22");
  my $a2  = gate("and",    "and2", qw(i21 i22));
  my $a3  = gate("and",    "and",  qw(and1 and2));
  my $o   = gate("output", "o", "and");
  my $s  = simulate({i11=>1, i12=>1, i21=>1, i22=>1});
  ok($s->steps         == 2);
  ok($s->values->{and} == 1);
 }
