#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/
#-------------------------------------------------------------------------------
# Create a test GDS2 file
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2024
#-------------------------------------------------------------------------------
use v5.34;
package Lisp::Memory;
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use GDS2;

makeDieConfess;

my $g = new GDS2(-fileName=>'>test.gds');
$g->printInitLib(-name=>'testlib');
$g->printBgnstr(-name=>'test');
$g->printPath(
                -layer=>6,
                -pathType=>0,
                -width=>2.4,
                -xy=>[0,0, 10.5,0, 10.5,3.3],
             );
$g->printSref(
                -name=>'contact',
                -xy=>[4,5.5],
             );
$g->printAref(
                -name=>'contact',
                -columns=>2,
                -rows=>3,
                -xy=>[0,0, 10,0, 0,15],
             );
$g->printEndstr;
$g->printBgnstr(-name => 'contact');
$g->printBoundary(
                -layer=>10,
                -xy=>[0,0, 1,0, 1,1, 0,1],
             );
$g->printEndstr;
$g->printEndlib();
