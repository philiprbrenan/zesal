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

sub maxSimulationSteps {100}                                                    # Maximum simulation steps

my %gates;                                                                      # Gates by output name

sub start()                                                                     # Start a circuit design
 {%gates = ();
 }

sub gate($$;$)                                                                  # A gate of some sort defined by its single output name
 {my ($type, $output, $inputs) = @_;                                            # Gate type, output name, input names to output from another gate

  $output =~ m(\A[a-z][a-z0-9_.:]*\Z)i or confess "Invalid gate name '$output'\n";

  $gates{$output} and confess "Gate $output has already been specified\n";

  if ($type =~ m(\Ainput\Z)i)                                                   # Input gates have no inputs
   {defined($inputs) and confess "No input hash allowed for input gate '$output'\n";
   }
  elsif ($type =~ m(\A(not|output)\Z)i)                                         # These gates have one input expressed as a name rather than a hash
   {!defined($inputs) and confess "Input name required for gate '$output'\n";
    ref($inputs) =~ m(hash)i and confess "Scalar input name required for '$output'\n";
    $inputs = {$output=>$inputs};                                               # Convert convenient scalar name to hash for consistency with gates in general
   }
  elsif ($type =~ m(\A(nxor|xor)\Z)i)                                           # These gates must have exactly two inputs expressed as a hash mapping input pin name to connection to a named gate.  These operations are associative.
   {!defined($inputs) and confess "Input hash required for gate '$output'\n";
    ref($inputs) =~ m(hash)i or confess "Inputs must be a hash of input names to outputs for '$output' to show the output accepted by each input. Input gates have no inputs, they are supplied instead during simulation\n";
    keys(%$inputs) == 2 or confess "Two inputs required for gate: '$output'\n";
   }
  elsif ($type =~ m(\A(and|nand|nor|or)\Z)i)                                    # These gates must have two or more inputs expressed as a hash mapping input pin name to connection to a named gate.  These operations are associative.
   {!defined($inputs) and confess "Input hash required for gate '$output'\n";
    ref($inputs) =~ m(hash)i or confess "Inputs must be a hash of input names to outputs for '$output' to show the output accepted by each input. Input gates have no inputs, they are supplied instead during simulation\n";
    keys(%$inputs) < 2 and confess "Two or more inputs required for gate: '$output'\n";
   }
  else                                                                          # Unknown gate type
   {my $possibleTypes = q(and|input|nand|nor|not|nxor|or|output|xor);           # Possible gate types
    confess "Unknown gate type '$type' for gate '$output', possible types are: $possibleTypes\n";
   }

  my $g = genHash("Icd::Designer::Gate",                                        # Gate
   type   => $type,                                                             # Gate type
   output => $output,                                                           # Output name
   inputs => $inputs,                                                           # Input names to driving outputs
  );

  $gates{$output} = $g                                                          # Record gate and return it
 }

sub checkIO(%)                                                                  # Check that every input is connected to one output
 {my (%options) = @_;                                                           # Options

  my %o;
  for my $G(sort keys %gates)                                                   # Find all inputs and outputs
   {my $g = $gates{$G};                                                         # Address gate
    next if $g->type =~ m(\Ainput\Z)i;                                          # Inputs are driven externally during simulation
    my %i = $g->inputs->%*;                                                     # Inputs for gate
    for my $i(sort keys %i)                                                     # Each input
     {my $o = $i{$i};                                                           # Output driving input
      if (!exists $gates{$o})                                                   # No driving output
       {confess "No output driving input '$i' on gate '$G'\n";
       }
      $o{$o}++                                                                  # Show that this output has been used
     }
   }

  for my $G(sort keys %gates)                                                   # Find all inputs and outputs
   {my $g = $gates{$G};                                                         # Address gate
    next if $g->type =~ m(\Aoutput\Z)i;
    $o{$G} or confess "Output from gate '$G' is never used\n";
   }
 }

sub simulate($%)                                                                # Simulate the set of gates until nothing changes.  This should be possible as feedback loops are banned.
 {my ($inputs, %options) = @_;                                                  # Hash of input names to values, options

  checkIO;                                                                      # Check all inputs are connected to valid gates and that all outputs are used

  my %values = %$inputs;                                                        # The current set of values contains justthe inouts at the start of the simulation

  my $t; for($t = 0; $t < maxSimulationSteps; ++$t)                             # Steps in time
   {my %changes;                                                                # Changes made
    for my $G(sort keys %gates)
     {my $g = $gates{$G};                                                       # Address gate
      my $t = $g->type;                                                         # Gate type
      next if $t =~ m(\Ainput\Z)i;                                              # No need to calculate value of input gates
      my %i = $g->inputs->%*;                                                   # Inputs to gate
      my @i = @values{values %i};                                               # Values of inputs to gates

      my $u = 0;                                                                # Number of undefined inputs
      for my $i(sort keys %i)
       {++$u unless defined $values{$i{$i}};
       }

      if (!$u)                                                                  # All inputs defined
       {my $r;                                                                  # Result of gate operation
        if ($t =~ m(\Aand|nand\Z)i)                                             # Elaborate an AND gate
         {my $z = 0;
          for my $i(@i)
           {++$z if !$i;
           }
          $r = $z ? 0 : 1;
          $r = !$r if $t =~ m(\Anand\Z)i;
         }
        elsif ($t =~ m(\A(nor|not|or|output)\Z)i)                               # Elaborate NOT, OR or OUTPUT gate
         {my $o = 0;
          for my $i(@i)
           {++$o if $i;
           }
          $r = $o ? 1 : 0;
          $r = !$r if $t =~ m(\Anor|not\Z)i;
         }
        elsif ($t =~ m(\A(nxor|xor)\Z)i)                                        # Elaborate XOR
         {$r = $i[0] ^ $i[1];
          $r = !$r if $t =~ m(\Anxor\Z)i;
         }
        else                                                                    # Unknown gate type
         {confess "Need implementation for '$t' gates";
         }
        $changes{$G} = $r unless defined($values{$G}) and $values{$G} == $r;    # Value computed by this gate
       }
     }

    last unless keys %changes;                                                  # Keep going until nothing changes
    for my $c(sort keys %changes)                                               # Update state of circuit
     {$values{$c} = $changes{$c};
     }
   }

  genHash("Idc::Designer::Simulation::Results",                                 # Simulation results
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
  ok($@ =~ m(Output from gate 'i1' is never used)i);
 }

if (1)                                                                          # Gate already specified
 {start;
        gate("input",  "i1");
  eval {gate("input",  "i1")};
  ok($@ =~ m(Gate i1 has already been specified));
 }

if (1)                                                                          # Check all inputs
 {start;
  gate("input",  "i1");
  gate("input",  "i2");
  gate("and",    "and1", {1=>q(i1), i2=>q(i2)});
  gate("output", "o",    q(an1));
  eval {simulate({i1=>1, i2=>1})};
  ok($@ =~ m(No output driving input '1' on gate 'o')i);
 }

latest:;
if (1)                                                                          # Single AND gate
 {start;
  gate("input",  "i1");
  gate("input",  "i2");
  gate("and",    "and1", {1=>q(i1), 2=>q(i2)});
  gate("output", "o", "and1");
  my $s  = simulate({i1=>1, i2=>1});
  ok($s->steps          == 2);
  ok($s->values->{and1} == 1);
 }

#latest:;
if (1)                                                                          # Three AND gates in a tree
 {start;
  gate("input",  "i11");
  gate("input",  "i12");
  gate("and",    "and1", {1=>q(i11),  2=>q(i12)});
  gate("input",  "i21");
  gate("input",  "i22");
  gate("and",    "and2", {1=>q(i21),  2=>q(i22)});
  gate("and",    "and",  {1=>q(and1), 2=>q(and2)});
  gate("output", "o", "and");
  my $s  = simulate({i11=>1, i12=>1, i21=>1, i22=>1});
  ok($s->steps         == 3);
  ok($s->values->{and} == 1);
     $s  = simulate({i11=>1, i12=>0, i21=>1, i22=>1});
  ok($s->steps         == 3);
  ok($s->values->{and} == 0);
 }

#latest:;
if (1)                                                                          # Two AND gates driving an OR gate a tree
 {start;
  gate("input",  "i11");
  gate("input",  "i12");
  gate("and",    "and1", {1=>q(i11),  2=>q(i12)});
  gate("input",  "i21");
  gate("input",  "i22");
  gate("and",    "and2", {1=>q(i21),  2=>q(i22)});
  gate("or",     "or",   {1=>q(and1), 2=>q(and2)});
  gate("output", "o", "or");
  my $s  = simulate({i11=>1, i12=>1, i21=>1, i22=>1});
  ok($s->steps         == 3);
  ok($s->values->{or}  == 1);
     $s  = simulate({i11=>1, i12=>0, i21=>1, i22=>1});
  ok($s->steps         == 3);
  ok($s->values->{or}  == 1);
     $s  = simulate({i11=>1, i12=>0, i21=>1, i22=>0});
  ok($s->steps         == 3);
  ok($s->values->{o}   == 0);
 }

#latest:;
if (1)                                                                          # 4 bit comparator
 {start;
  gate("input",  "a$_") for 1..4;                                               # First number
  gate("input",  "b$_") for 1..4;                                               # Second number
  gate("nxor",   "e$_", {1=>"a$_", 2=>"b$_"}) for 1..4;                         # Test each bit for equality
  gate("and",    "and", {map{$_=>"e$_"} 1..4});                                 # And tests together to get equality
  gate("output", "out", "and");
  is_deeply(simulate({a1=>1, a2=>0, a3=>1, a4=>0,
                      b1=>1, b2=>0, b3=>1, b4=>0})->values->{out}, 1);
  is_deeply(simulate({a1=>1, a2=>1, a3=>1, a4=>0,
                      b1=>1, b2=>0, b3=>1, b4=>0})->values->{out}, 0);
 }
