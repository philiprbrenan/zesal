#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/ -I/home/phil/perl/cpan/GitHubCrud/lib/
#-------------------------------------------------------------------------------
# Zip
# Philip R Brenan at gmail dot com, Appa Apps Ltd Inc., 2023
#-------------------------------------------------------------------------------
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use feature qw(say current_sub);

my $home = q(/home/phil/zesal/SiliconCatalyst/);                                # Home
my $z    = q(SiliconCatalyst);

unlink $z;

say STDERR qx(cd $home; zip $z *.htm *.html);
