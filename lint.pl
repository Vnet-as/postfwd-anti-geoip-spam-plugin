#!/usr/bin/perl

use strict;
use Perl::Critic;

my $file = "postfwd-anti-spam.plugin";
my $critic = Perl::Critic->new();
my @violations = $critic->critique($file);
print @violations;
