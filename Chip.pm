#!/usr/bin/perl -I/home/phil/perl/cpan/SvgSimple/lib/
#-------------------------------------------------------------------------------
# Design a silicon chip by combining gates and sub chips.
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2023
#-------------------------------------------------------------------------------
use v5.34;
package Silicon::Chip;
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use Svg::Simple;

makeDieConfess;

sub maxSimulationSteps {100}                                                    # Maximum simulation steps
sub gateNotIO          {0}                                                      # Not an input or output gate
sub gateInternalInput  {1}                                                      # Input gate on an internal chip
sub gateInternalOutput {2}                                                      # Output gate on an internal chip
sub gateExternalInput  {3}                                                      # Input gate on the external chip
sub gateExternalOutput {4}                                                      # Output gate on the external chip
sub gateOuterInput     {5}                                                      # Input gate on the external chip connecting to the outer world
sub gateOuterOutput    {6}                                                      # Output gate on the external chip connecting to the outer world

sub newChip(%)                                                                  # Create a new chip
 {my (%options) = @_;                                                           # Options
  genHash(__PACKAGE__,                                                          # Chip description
    name    => $options{name   } // "Unnamed chip: ".timeStamp,                 # Name of chip
    gates   => $options{gates  } // {},                                         # Gates in chip
    installs=> $options{chips  } // [],                                         # Chips installed within the chip
   );
 }

sub newGate($$$$)                                                               # Make a gate
 {my ($chip, $type, $output, $inputs) = @_;                                     # Chip, gate type, output name, input names to output from another gate

  my $g = genHash("Silicon::Chip::Gate",                                        # Gate
   type     => $type,                                                           # Gate type
   output   => $output,                                                         # Output name which is used as the name of the gate as well
   inputs   => $inputs,                                                         # Input names to driving outputs
   io       => gateNotIO,                                                       # Whether an input/output gate or not
  );
 }

my sub cloneGate($$)                                                            # Clone a gate
 {my ($chip, $gate) = @_;                                                       # Chip, gate
  newGate($chip, $gate->type, $gate->output, $gate->inputs)
 }

my sub renameGateInputs($$$)                                                    # Rename the inputs of a gate
 {my ($chip, $gate, $name) = @_;                                                # Chip, gate, prefix name
  for my $p(qw(inputs))
   {my %i;
    my $i = $gate->inputs;
    for my $n(sort keys %$i)
     {$i{$n} = sprintf "(%s %s)", $name, $$i{$n};
     }
    $gate->inputs = \%i;
   }
  $gate
 }

my sub renameGate($$$)                                                             # Rename a gate by adding a prefix
 {my ($chip, $gate, $name) = @_;                                                # Chip, gate, prefix name
  $gate->output = sprintf "(%s %s)", $name, $gate->output;
  $gate
 }

sub install($$$%)                                                               # Install a chip within another chip specifying the connections between the inner and outer chip.  The same chip can be installed multiple times as each chip description is read only.
 {my ($chip, $subChip, $inputs, $outputs, %options) = @_;                       # Outer chip, inner chip, inputs of inner chip to to outputs of outer chip, outputs of inner chip to inputs of outer chip
  my $c = genHash("Chip::Install",                                              # Installation of a chip within a chip
    chip    => $subChip,                                                        # Chip being installed
    inputs  => $inputs,                                                         # Outputs of outer chip to inputs of inner chip
    outputs => $outputs,                                                        # Outputs of inner chip to inputs of outer chip
   );
  push $chip->installs->@*, $c;                                                 # Install chip
  $c
 }

sub gate($$$;$)                                                                 # A gate of some sort defined by its single output name
 {my ($chip, $type, $output, $inputs) = @_;                                     # Chip, gate type, output name, input names to output from another gate
  my $gates = $chip->gates;                                                     # Gates implementing the chip

  $output =~ m(\A[a-z][a-z0-9_.:]*\Z)i or confess "Invalid gate name '$output'\n";
  $$gates{$output} and confess "Gate $output has already been specified\n";

  if ($type =~ m(\A(input)\Z)i)                                                 # Input gates input to themselves unless they have been connected to an output gate during sub chip expansion
   {defined($inputs) and confess "No input hash allowed for input gate '$output'\n";
    $inputs = {$output=>$output};                                               # Convert convenient scalar name to hash for consistency with gates in general
   }
  elsif ($type =~ m(\A(output)\Z)i)                                             # Output has one optional scalar value naming its input if known at this point
   {if (defined($inputs))
     {ref($inputs) and confess "Scalar input name required for output gate: '$output'\n";
      $inputs = {$output=>$inputs};                                             # Convert convenient scalar name to hash for consistency with gates in general
     }
   }
  elsif ($type =~ m(\A(not)\Z)i)                                                # These gates have one input expressed as a name rather than a hash
   {!defined($inputs) and confess "Input name required for gate '$output'\n";
    $type =~ m(\Anot\Z)i and ref($inputs) =~ m(hash)i and confess "Scalar input name required for '$output'\n";
    $inputs = {$output=>$inputs};                                               # Convert convenient scalar name to hash for consistency with gates in general
   }
  elsif ($type =~ m(\A(nxor|xor|gt|ngt|lt|nlt)\Z)i)                             # These gates must have exactly two inputs expressed as a hash mapping input pin name to connection to a named gate.  These operations are associative.
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

  $chip->gates->{$output} = newGate($chip, $type, $output, $inputs);            # Construct gate, save it and return it
 }

my sub getGates($%)                                                             # Get the gates of a chip and all it installed sub chips
 {my ($chip, %options) = @_;                                                    # Chip, options

  my %outerGates;
  for my $g(values $chip->gates->%*)                                            # Copy gates from outer chip
   {my $G = $outerGates{$g->output} = cloneGate($chip, $g);
    if    ($G->type =~ m(\Ainput\Z)i)  {$G->io = gateExternalInput}             # Input gate on outer chip
    elsif ($G->type =~ m(\Aoutput\Z)i) {$G->io = gateExternalOutput}            # Output gate on outer chip
   }

  my @installs = $chip->installs->@*;                                           # Each sub chip used in this chip

  for my $install(keys @installs)                                               # Each sub chip
   {my $s = $installs[$install];                                                # Sub chip installed in this chip
    my $n = $s->chip->name;                                                     # Name of sub chip
    my $innerGates = __SUB__->($s->chip);                                       # Gates in sub chip

    for my $G(sort keys %$innerGates)                                           # Each gate in sub chip
     {my $g = $$innerGates{$G};                                                 # Gate in sub chip
      my $o = $g->output;                                                       # Name of gate
      my $copy = cloneGate $chip, $g;                                           # Clone gate from chip description
      my $newGateName = sprintf "$n %d", $install+1;                            # Rename gates to prevent name collisions from the expansions of the definitions of the inner chips

      if ($copy->type =~ m(\Ainput\Z)i)                                         # Input gate on inner chip - connect to corresponding output gate on containing chip
       {my $in = $copy->output;                                                 # Name of input gate on inner chip
        my $o  = $s->inputs->{$in};
           $o or confess "No connection specified to inner input gate '$in' on sub chip '$n'";
        my $O  = $outerGates{$o};
           $O or confess "No outer output gate '$o' to connect to inner input gate '$in' on sub chip '$n'";
        my $ot = $O->type;
        my $on = $O->output;
           $ot =~ m(\Aoutput\Z)i or confess "Output gate required for connection to $in on sub chip $n, not gate $on of type $ot";
        $copy->inputs = {1 => $o};                                              # Connect inner input gate to outer output gate
        renameGate $chip, $copy, $newGateName;                                  # Add chip name to gate to disambiguate it from any other gates
        $copy->io = gateInternalInput;                                          # Mark this as an internal input gate
       }

      elsif ($copy->type =~ m(\Aoutput\Z)i)                                     # Output gate on inner chip - connect to corresponding input gate on containing chip
       {my $on = $copy->output;                                                 # Name of output gate on outer chip
        my $i  = $s->outputs->{$on};
           $i or confess "No connection specified to inner output gate '$on' on sub chip '$n'";
        my $I  = $outerGates{$i};
           $I or confess "No outer input gate '$i' to connect to inner output gate $on on sub chip '$n'";
        my $it = $I->type;
        my $in = $I->output;
           $it =~ m(\Ainput\Z)i or confess "Input gate required for connection to '$in' on sub chip '$n', not gate '$in' of type '$it'";
        renameGateInputs $chip, $copy, $newGateName;
        renameGate       $chip, $copy, $newGateName;
        $I->inputs = {11 => $copy->output};                                     # Connect inner output gate to outer input gate
        $copy->io  = gateInternalOutput;                                        # Mark this as an internal output gate
       }
      else                                                                      # Rename all other gate inputs
       {renameGateInputs $chip, $copy, $newGateName;
        renameGate       $chip, $copy, $newGateName;
       }

      $outerGates{$copy->output} = $copy;                                       # Install gate with new name now it has been connected up
     }
   }
  \%outerGates                                                                  # Return all the gates in the chip extended by its sub chips
 }

my sub checkIO($$%)                                                             # Check that every input is connected to one output
 {my ($chip, $gates, %options) = @_;                                            # Chip, gates in chip plus all sub chips as supplied by L<getGates>.

  my %o;
  for my $G(sort keys %$gates)                                                  # Find all inputs and outputs
   {my $g = $$gates{$G};                                                        # Address gate
    ##next unless $g->inputs;                                                     # Inputs are driven externally during simulation
    my %i = $g->inputs->%*;                                                     # Inputs for gate
    for my $i(sort keys %i)                                                     # Each input
     {my $o = $i{$i};                                                           # Output driving input
      if (!exists $$gates{$o})                                                  # No driving output
       {confess "No output driving input '$o' on gate '$G'\n";
       }
      elsif ($g->type !~ m(\Ainput\Z)i or ($i{$g->output}//'') ne $g->output)   # Input gate at highest level driving itself so we ignore itr so that if nothing else sues this gate it gets flagged as non driving
       {$o{$o}++                                                                # Show that this output has been used
       }
     }
   }

  for my $G(sort keys %$gates)                                                  # Check all inputs and outputs are being used
   {my $g = $$gates{$G};                                                        # Address gate
    next if $g->type =~ m(\Aoutput\Z)i;
    $o{$G} or confess "Output from gate '$G' is never used\n";
   }
 }

my sub setOuterGates($$%)                                                       # Set outer gates on extenal chip that connect to the outer world
 {my ($chip, $gates, %options) = @_;                                            # Chip, gates in chip plus all sub chips as supplied by L<getGates>.

  for my $G(sort keys %$gates)                                                  # Find all inputs and outputs
   {my $g = $$gates{$G};                                                        # Address gate
    next unless $g->io == gateExternalInput;                                    # Input on external chip
    my ($i) = values $g->inputs->%*;
    $g->io = gateOuterInput if $g->output eq $i;                                # Unconnected input gates relfect back on themselves - this is a short hand way of discovering such gates
   }

  gate: for my $G(sort keys %$gates)                                            # Find all inputs and outputs
   {my $g = $$gates{$G};                                                        # Address gate
    next unless $g->io == gateExternalOutput;                                   # Output on external chip
    for my $H(sort keys %$gates)                                                # Gates driven by this gate
     {next if $G eq $H;
      my %i = $$gates{$H}->inputs->%*;                                          # Inputs to this gate
      for my $I(sort keys %i)                                                   # Each input
       {next gate if $i{$I} eq $G;                                              # Found a gate that accepts input from this gate
       }
     }
    $g->io = gateOuterOutput;                                                   # Does not drive any other gate
   }
 }

my sub removeExcessIO($$%)                                                      # Remove unneeded IO gates
 {my ($chip, $gates, %options) = @_;                                            # Chip, gates in chip plus all sub chips as supplied by L<getGates>.

  gate: for my $G(sort keys %$gates)                                            # Find all inputs and outputs
   {my $g = $$gates{$G};                                                        # Address gate
    next unless $g->io;                                                         # Skip non IO gates
    next if     $g->io == gateOuterInput or $g->io == gateOuterOutput;          # Cannot be collapsed
    my ($n) = values $g->inputs->%*;                                            # Name of the gate driving this gate

    for my $H(sort keys %$gates)                                                # Gates driven by this gate
     {next if $G eq $H;
      my $h = $$gates{$H};                                                      # Address gate
      my %i = $h->inputs->%*;                                                   # Inputs
      for my $i(sort keys %i)                                                   # Each input
       {if ($i{$i} eq $G)                                                       # Found a gate that accepts input from this gate
         {$h->inputs->{$i} = $n;                                                # Bypass io gate
          delete $$gates{$G};
          next gate;
         }
       }
     }
   }
 }

my sub simulationStep($$$%)                                                     # One step in the simulation of the chip after expansion of inner chips
 {my ($chip, $gates, $values, %options) = @_;                                   # Chip, gates, current value of each gate, options
  my %changes;                                                                  # Changes made

  for my $G(keys %$gates)                                                       # Output for each gate
   {my $g = $$gates{$G};                                                        # Address gate
    my $t = $g->type;                                                           # Gate type
    my $n = $g->output;                                                         # Gate name
    my %i = $g->inputs->%*;                                                     # Inputs to gate
    my @i = map {$$values{$i{$_}}} sort keys %i;                                # Values of inputs to gates in input pin name order

    my $u = 0;                                                                  # Number of undefined inputs
    for my $i(@i)
     {++$u unless defined $i;
     }

    if (!$u)                                                                    # All inputs defined
     {my $r;                                                                    # Result of gate operation
      if ($t =~ m(\Aand|nand\Z)i)                                               # Elaborate and AND gate
       {my $z = grep {!$_} @i;                                                  # Count zero inputs to AND gate
        $r = $z ? 0 : 1;
        $r = !$r if $t =~ m(\Anand\Z)i;
       }
      elsif ($t =~ m(\A(input)\Z)i)                                             # An input gate takes its value from the list of inputs or from an output gate in an inner chip
       {if (my @i = values $g->inputs->%*)                                      # Get the value of the input gate from the current values
         {my $n = $i[0];
             $r = $$values{$n};
         }
        else
         {confess "No driver for input gate $n";
         }
       }
      elsif ($t =~ m(\A(continue|nor|not|or|output)\Z)i)                        # Elaborate NOT, OR or OUTPUT gate. A CONTINUE gate places its single input unchanged on its output
       {my $o = grep {$_} @i;                                                   # Count one inputs
        $r = $o ? 1 : 0;
        $r = $r ? 0 : 1 if $t =~ m(\Anor|not\Z)i;
       }
      elsif ($t =~ m(\A(nxor|xor)\Z)i)                                          # Elaborate XOR
       {@i == 2 or confess;
        $r = $i[0] ^ $i[1] ? 1 : 0;
        $r = $r ? 0 : 1 if $t =~ m(\Anxor\Z)i;
       }
      elsif ($t =~ m(\A(gt|ngt)\Z)i)                                            # Elaborate A GT B - the input pins are assumed to be sorted by name with the first pin as A and the second as B
       {@i == 2 or confess;
        $r = $i[0] > $i[1] ? 1 : 0;
        $r = $r ? 0 : 1 if $t =~ m(\Angt\Z)i;
       }
      elsif ($t =~ m(\A(lt|nlt)\Z)i)                                            # Elaborate A LT B - the input pins are assumed to be sorted by name with the first pin as A and the second as B
       {@i == 2 or confess;
        $r = $i[0] < $i[1] ? 1 : 0;
        $r = $r ? 0 : 1 if $t =~ m(\Anlt\Z)i;
       }
      else                                                                      # Unknown gate type
       {confess "Need implementation for '$t' gates";
       }
      $changes{$G} = $r unless defined($$values{$G}) and $$values{$G} == $r;    # Value computed by this gate
     }
   }
  %changes
 }

my sub simulationResults($$%)                                                      # Simulation result
 {my ($chip, $values, %options) = @_;                                           # Chip, hash of final values for each gate, options

  genHash("Idc::Designer::Simulation::Results",                                 # Simulation results
    steps  => $options{steps},                                                  # Number of steps to reach stability
    values => $values,                                                          # Values of every output at point of stability
   );
 }

#D1 Visualize                                                                   # Visualize the chip in various ways

my sub orderGates($$%)                                                          # Order the gates so that input are first, output are last and the rest are in between
 {my ($chip, $gates, %options) = @_;                                            # Chip, gates, options
  my @i; my @r; my @o;
  for my $G(sort keys %$gates)                                                  # Dump each gate one per line
   {my $g = $$gates{$G};
    push @i, $G if $g->type =~ m(\Ainput\Z)i;
    push @o, $G if $g->type =~ m(\Aoutput\Z)i;
    push @r, $G if $g->type !~ m(\A(in|out)put\Z)i;
   }
  @i = sort @i;  @o = sort @o; @r = sort @r;
  (@i, @r, @o)
 }

my sub dumpGates($$%)                                                           # Dump some gates
 {my ($chip, $gates, %options) = @_;                                            # Chip, gates, options
  my @s;
  for my $G(orderGates($chip, $gates))                                          # Dump each gate one per line
   {my $g = $$gates{$G};
    my %i = $g->inputs ? $g->inputs->%* : ();
    my $p = sprintf "%-12s: %2d %-8s", $g->output, $g->io, $g->type;            # Instruction name and type
    if (my @i = map {$i{$_}} sort keys %i)                                      # Add actual inputs in same line sorted in input pin name
     {$p .= join " ", @i;
     }
    push @s, $p;
   }
  owf fpe($options{dumpGates}, q(txt)), join "\n", @s;                          # Write representation of gates as text to the named file
 }

my sub newGatePosition(%)                                                       # Gate position
 {my (%options) = @_;                                                           # Options

  genHash("Silicon::Chip::Gate::Position",                                      # Gate position
    gate  => $options{gate}  // undef,                                          # Gate
    x     => $options{x}     // undef,                                          # X position of gate
    y     => $options{y}     // undef,                                          # Y position of gate
    width => $options{width} // undef,                                          # Width of gate
   )
 }

my sub svgGates($$%)                                                            # Dump some gates
 {my ($chip, $gates, %options) = @_;                                            # Chip, gates, options

  my %p;                                                                        # Dimensions and drawing positions of gates
  if (1)                                                                        # Position each gate
   {my $x = 0; my $y = 0; my $pg;
    for my $G(orderGates($chip, $gates))                                        # Each gate
     {my $g  = $$gates{$G};
      my %i  = $g->inputs ? $g->inputs->%* : ();
      my $w  = keys %i;
      $x++ if defined($pg) and $pg->io and !$g->io;                             # Move first non input gate right of the input gate stack
      $p{$G} = newGatePosition(gate=>$g, x=>$x, y=>$y, width=>$w);
      $x += $w unless $g->io;                                                   # IO gates can be stacked vertically because they are never connected vertically
      $y += 1.2;
      $pg = $g;                                                                 # Previous gate seen
     }
   }

  my $s = Svg::Simple::new(defaults=>{stroke_width=>0.02, font_size=>0.2});     # Draw each gate via Svg

  for my $P(sort keys %p)                                                       # Each gate with text describing it
   {my $p = $p{$P};
    my $x = $p->x; my $y = $p->y; my $w = $p->width; my $g = $p->gate;          # Position of gate

    my $color = sub
     {return "red"  if $g->io == gateOuterOutput;
      return "blue" if $g->io == gateOuterInput;
      "green"
     }->();

    if ($g->io)                                                                 # Circle for io pin
     {$s->circle(cx=>$x+1/2, cy=>$y+1/2, r=>1/2, fill=>"white", stroke=>$color);
     }
    else                                                                        # Rectangle for non io gate
     {$s->rect(x=>$x, y=>$y, width=>$w, height=>1, fill=>"white", stroke=>$color);
     }

    $s->text(x=>$x+$w/2, y=>$y + 2/5, fill=>"red",      text_anchor=>"middle", alignment_baseline=>"middle", cdata=>$g->type);
    $s->text(x=>$x+$w/2, y=>$y + 4/5, fill=>"darkblue", text_anchor=>"middle", alignment_baseline=>"middle", cdata=>$g->output);

    if ($g->io != gateOuterInput)                                                                # Not an input pin
     {my %i = $g->inputs ? $g->inputs->%* : ();
      my @i = sort values %i;                                                   # Connections to each gate
      for my $i(keys @i)                                                        # Connections to each gate
       {my $P = $p{$i[$i]};                                                     # Source gate
        my $X = $P->x; my $Y = $P->y; my $W = $P->width; my $G = $P->gate;      # Position of gate
        my $dx = $i + 1/2;
        my $dy = $Y < $y ?  0 : 1;
        my $dX = $X < $x ? $W : 0;
        my $dY = $Y < $y ?  0 : 0;
        my $cx = $x+$dx;                                                        # Horizontal line corner x
        my $cy = $Y+$dY+1/2;                                                    # Horizontal line corner y

        my $xc = $X < $x ? q(black) : q(darkBlue);                              # Horizontal line color
        $s->line(x1=>$X+$dX, x2=>$cx, y1=>$cy, y2=>$cy,    stroke=>$xc);        # Horizontal lines

        my $yc = $Y < $y ? q(purple) : q(darkRed);                              # Vertical lines
        $s->line(x1=>$cx,   x2=>$cx, y1=>$cy, y2=>$y+$dy, stroke=>$yc);
        $s->circle(cx=>$cx, cy=>$cy, r=>0.04, fill=>"black");
       }
     }
    owf(fpe($options{svg}, q(svg)), $s->print);
   }
 }

#D1 Simulate                                                                    # Simulate the behavior of the chip.

sub simulate($$%)                                                               # Simulate the set of gates until nothing changes.  This should be possible as feedback loops are banned.
 {my ($chip, $inputs, %options) = @_;                                           # Chip, Hash of input names to values, options
  my $gates = getGates $chip;                                                   # Gates implementing the chip and all of its sub chips
  setOuterGates($chip, $gates);                                                 # Set the outer gates which are to be connected to in the real word
  removeExcessIO($chip, $gates);                                                # By pass and then remove all interior IO gates as they are no longer needed


  dumpGates($chip, $gates, %options) if $options{dumpGates};                    # Print the gates
  svgGates ($chip, $gates, %options) if $options{svg};                          # Draw the gates using svg
  checkIO $chip, $gates;                                                        # Check all inputs are connected to valid gates and that all outputs are used

  my %values = %$inputs;                                                        # The current set of values contains just the inputs at the start of the simulation.

  my $T = maxSimulationSteps;                                                   # Maximum steps
  for my $t(0..$T)                                                              # Steps in time
   {my %changes = simulationStep $chip, $gates, \%values;                       # Changes made

    return simulationResults $chip, \%values, steps=>$t unless keys %changes;   # Keep going until nothing changes

    for my $c(keys %changes)                                                    # Update state of circuit
     {$values{$c} = $changes{$c};
     }
   }

  confess "Out of time after $T steps";                                         # Not enough steps available
 }


#D0 Tests                                                                       # Tests and examples

eval {return 1} unless caller;
eval "use Test::More qw(no_plan);";
eval "Test::More->builder->output('/dev/null');" if -e q(/home/phil2/);
eval {goto latest};

if (1)                                                                          # Unused output
 {my $c = newChip;
  $c->gate("input",  "i1");
  eval {$c->simulate({i1=>1})};
  ok($@ =~ m(Output from gate 'i1' is never used)i);
 }

if (1)                                                                          # Gate already specified
 {my $c = newChip;
        $c->gate("input",  "i1");
  eval {$c->gate("input",  "i1")};
  ok($@ =~ m(Gate i1 has already been specified));
 }

#latest:;
if (1)                                                                          # Check all inputs
 {my $c = newChip;
  $c->gate("input",  "i1");
  $c->gate("input",  "i2");
  $c->gate("and",    "and1", {1=>q(i1), i2=>q(i2)});
  $c->gate("output", "o",    q(an1));
  eval {$c->simulate({i1=>1, i2=>1})};
  ok($@ =~ m(No output driving input 'an1' on gate 'o')i);
 }

#latest:;
if (1)                                                                          # Single AND gate
 {my $c = newChip;
  $c->gate("input",  "i1");
  $c->gate("input",  "i2");
  $c->gate("and",    "and1", {1=>q(i1), 2=>q(i2)});
  $c->gate("output", "o", "and1");
  my $s = $c->simulate({i1=>1, i2=>1});
  ok($s->steps          == 2);
  ok($s->values->{and1} == 1);
 }

#latest:;
if (1)                                                                          # Three AND gates in a tree
 {my $c = newChip;
  $c->gate("input",  "i11");
  $c->gate("input",  "i12");
  $c->gate("and",    "and1", {1=>q(i11),  2=>q(i12)});
  $c->gate("input",  "i21");
  $c->gate("input",  "i22");
  $c->gate("and",    "and2", {1=>q(i21),  2=>q(i22)});
  $c->gate("and",    "and",  {1=>q(and1), 2=>q(and2)});
  $c->gate("output", "o", "and");
  my $s = $c->simulate({i11=>1, i12=>1, i21=>1, i22=>1});
  ok($s->steps         == 3);
  ok($s->values->{and} == 1);
     $s = $c->simulate({i11=>1, i12=>0, i21=>1, i22=>1});
  ok($s->steps         == 3);
  ok($s->values->{and} == 0);
 }

#latest:;
if (1)                                                                          # Two AND gates driving an OR gate a tree
 {my $c = newChip;
  $c->gate("input",  "i11");
  $c->gate("input",  "i12");
  $c->gate("and",    "and1", {1=>q(i11),  2=>q(i12)});
  $c->gate("input",  "i21");
  $c->gate("input",  "i22");
  $c->gate("and",    "and2", {1=>q(i21),  2=>q(i22)});
  $c->gate("or",     "or",   {1=>q(and1), 2=>q(and2)});
  $c->gate("output", "o", "or");
  my $s = $c->simulate({i11=>1, i12=>1, i21=>1, i22=>1});
  ok($s->steps         == 3);
  ok($s->values->{or}  == 1);
     $s  = $c->simulate({i11=>1, i12=>0, i21=>1, i22=>1});
  ok($s->steps         == 3);
  ok($s->values->{or}  == 1);
     $s  = $c->simulate({i11=>1, i12=>0, i21=>1, i22=>0});
  ok($s->steps         == 3);
  ok($s->values->{o}   == 0);
 }

#latest:;
if (1)                                                                          # 4 bit comparator
 {my $B = 4;
  my $c = newChip;
  $c->gate("input",  "a$_") for 1..$B;                                          # First number
  $c->gate("input",  "b$_") for 1..$B;                                          # Second number
  $c->gate("nxor",   "e$_", {1=>"a$_", 2=>"b$_"}) for 1..$B;                    # Test each bit for equality
  $c->gate("and",    "and", {map{$_=>"e$_"} 1..$B});                            # And tests together to get equality
  $c->gate("output", "out", "and");
  is_deeply($c->simulate({a1=>1, a2=>0, a3=>1, a4=>0,
                          b1=>1, b2=>0, b3=>1, b4=>0}, svg=>"svg/Compare4")->values->{out}, 1);
  is_deeply($c->simulate({a1=>1, a2=>1, a3=>1, a4=>0,
                          b1=>1, b2=>0, b3=>1, b4=>0})->values->{out}, 0);
 }

#latest:;
if (1)                                                                          # 4 bit 'a' greater than 'b' - the pins used to input 'a' must be alphabetically less than those used for 'b'
 {my $B = 4;
  my $c = newChip;
  $c->gate("input",  "a$_") for 1..$B;                                          # First number
  $c->gate("input",  "b$_") for 1..$B;                                          # Second number
  $c->gate("nxor",   "e$_", {1=>"a$_", 2=>"b$_"}) for 1..$B-1;                  # Test each bit for equality
  $c->gate("gt",     "g$_", {1=>"a$_", 2=>"b$_"}) for 1..$B;                    # Test each bit pair for greater
  $c->gate("and",    "c2",  {1=>"e1", 2=>                  "g2"});              # Greater on bit 2 and all preceding bits are equal
  $c->gate("and",    "c3",  {1=>"e1", 2=>"e2", 3=>         "g3"});              # Greater on bit 3 and all preceding bits are equal
  $c->gate("and",    "c4",  {1=>"e1", 2=>"e2", 3=>"e3", 4=>"g4"});              # Greater on bit 4 and all preceding bits are equal
  $c->gate("or",     "or",  {1=>"g1", 2=>"c2", 3=>"c3", 4=>"c4"});              # Any set bit indicates that 'a' is greater than 'b'
  $c->gate("output", "out", "or");
  is_deeply($c->simulate({a1=>1, a2=>0, a3=>1, a4=>0,
                         b1=>1, b2=>0, b3=>1, b4=>0})->values->{out}, 0);
  is_deeply($c->simulate({a1=>1, a2=>1, a3=>1, a4=>0,
                         b1=>1, b2=>0, b3=>1, b4=>0})->values->{out}, 1);
 }

#latest:;
if (1)                                                                          # Masked multiplexer: copy B bit word selected by mask from W possible locations
 {my $B = 4; my $W = 4;
  my $c = newChip;
  for my $w(1..$W)                                                              # Input words
   {$c->gate("input", "s$w");                                                   # Selection mask
    for my $b(1..$B)                                                            # Bits of input word
     {$c->gate("input", "i$w$b");
      $c->gate("and",   "s$w$b", {1=>"i$w$b", 2=>"s$w"});
     }
   }
  for my $b(1..$B)                                                              # Or selected bits together to make output
   {$c->gate("or",     "c$b", {map {$_=>"s$b$_"} 1..$W});                       # Combine the selected bits to make a word
    $c->gate("output", "o$b", "c$b");                                           # Output the word selected
   }
  my $s = $c->simulate(
   {s1 =>0, s2 =>0, s3 =>1, s4 =>0,
    i11=>0, i12=>0, i13=>0, i14=>1,
    i21=>0, i22=>0, i23=>1, i24=>0,
    i31=>0, i32=>1, i33=>0, i34=>0,
    i41=>1, i42=>0, i43=>0, i44=>0});

  is_deeply([@{$s->values}{qw(o1 o2 o3 o4)}], [qw(0 0 1 0)]);                   # Number selected by mask
  is_deeply($s->steps, 3);
 }

#latest:;
if (1)                                                                          # Rename a gate
 {my $i = newChip(name=>"inner");
          $i->gate("input", "i");
  my $n = $i->gate("not",   "n",  "i");
          $i->gate("output","io", "n");

  my $ci = cloneGate $i, $n;
  renameGate $i, $ci, "aaa";
  is_deeply($ci->inputs,   { n => "i" });
  is_deeply($ci->output,  "(aaa n)");
  is_deeply($ci->io, 0);
 }

#latest:;
=pod
 Oi1 -> Oo1-> Ii->In->Io -> Oi2 -> Oo
=cut

if (1)                                                                          # Install one inside another chip, specifically obe chip that performs NOT is installed three times sequentially to flip a value
 {my $i = newChip(name=>"inner");
     $i->gate("input", "Ii");
     $i->gate("not",   "In", "Ii");
     $i->gate("output","Io", "In");

  my $o = newChip(name=>"outer");
     $o->gate("input",    "Oi1");
     $o->gate("output",   "Oo1", "Oi1");
     $o->gate("input",    "Oi2");
     $o->gate("output",    "Oo", "Oi2");

  $o->install($i, {Ii=>"Oo1"}, {Io=>"Oi2"});
  my $s = $o->simulate({Oi1=>1}, dumpGatesOff=>"dump/not1", svg=>"svg/not1");
  is_deeply($s, {steps  => 2, values => { "(inner 1 In)" => 0, "Oi1" => 1, "Oo" => 0 }});
 }

#latest:;
if (1)                                                                          # Install one inside another chip, specifically obe chip that performs NOT is installed three times sequentially to flip a value
 {my $i = newChip(name=>"inner");
     $i->gate("input", "Ii");
     $i->gate("not",   "In", "Ii");
     $i->gate("output","Io", "In");

  my $o = newChip(name=>"outer");
     $o->gate("input",    "Oi1");
     $o->gate("output",   "Oo1", "Oi1");
     $o->gate("input",    "Oi2");
     $o->gate("output",   "Oo2", "Oi2");
     $o->gate("input",    "Oi3");
     $o->gate("output",   "Oo3", "Oi3");
     $o->gate("input",    "Oi4");
     $o->gate("output",    "Oo", "Oi4");

  $o->install($i, {Ii=>"Oo1"}, {Io=>"Oi2"});
  $o->install($i, {Ii=>"Oo2"}, {Io=>"Oi3"});
  $o->install($i, {Ii=>"Oo3"}, {Io=>"Oi4"});
  my $s = $o->simulate({Oi1=>1}, dumpGatesOff=>"dump/not3", svg=>"svg/not3");
  is_deeply($s->values->{Oo}, 0);
 }

#latest:;
#if (1)                                                                         # Find smallest key bigger than the specified key
# {my $B = 4; my $W = 4;
#  start;
#  for my $w(1..$W)                                                             # Input words
#   {$c->gate("input", "s$w");                                                  # Selection mask
#    for my $b(1..$B)                                                           # Bits of input word
#     {$c->gate("input", "i$w$b");
#      $c->gate("and",   "s$w$b", {1=>"i$w$b", 2=>"s$w"});
#     }
#   }
#  for my $b(1..$B)                                                             # Or selected bits together to make output
#   {$c->gate("or",     "c$b", {map {$_=>"s$b$_"} 1..$W});                      # Combine the selected bits to make a word
#    $c->gate("output", "o$b", "c$b");                                          # Output the word selected
#   }
#  my $s = simulate(
#   {s1 =>0, s2 =>0, s3 =>1, s4=>0,
#    i11=>0, i12=>0, i13=>0, i14=>1,
#    i21=>0, i22=>0, i23=>1, i24=>0,
#    i31=>0, i32=>1, i33=>0, i34=>0,
#    i41=>1, i42=>0, i43=>0, i44=>0});
#  is_deeply($s->values->{o1}, 0);
#  is_deeply($s->values->{o2}, 0);
#  is_deeply($s->values->{o3}, 1);
#  is_deeply($s->values->{o4}, 0);
#
#  is_deeply($s->steps, 3);
# }
#
