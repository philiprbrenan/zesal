#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/
#-------------------------------------------------------------------------------
# Cost structure
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2024
#-------------------------------------------------------------------------------
use v5.34;
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);

my $ex    = 16.5;                                                               # Exchange rate persos per  dollar
my $en    = 10;                                                                 # Number of engineers
my $enSal = 1000 * int(13 * 21000 / $ex / 1000);                                # Annual salary for one engineer in dollars

my $d = [
["Digital engineers in Mexico" => sprintf("%5d", $en * $enSal)],
["Office/Equipment"            => 40e3],
["Management US"               => 100e3],
["6 runs on MOSIS"             => 25e3*6],
["Exingencies"                 => 50e3],
];

say STDERR formatTable($d, [qw(Item Cost)]);

my @h = <<END;
<table>
<tr><th>Item<th>Cost
END

my $T = 0;
for my $c(@$d)
 {my ($desc, $cost) = @$c;
   push @h, <<END;
<tr><td>$desc<td align=right>$cost
END
   $T += $cost;
 }

push @h, <<END;
</table>
<p>Total cost for one year in US dollars: $T
END

say STDERR join "\n", @h;
