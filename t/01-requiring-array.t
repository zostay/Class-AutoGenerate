#!/usr/bin/env perl
use strict;
use warnings;

use Test::More tests => 9;

package TestApp::Requiring::Regex;
use Class::AutoGenerate -base;

requiring [ 'Planets::Mercury', 'Planets::Venus', 'Planets::Earth',
            'Planets::Mars', 'Planets::Jupiter', 'Planets::Saturn',
            'Planets::Uranus', 'Planets::Neptune' ]
    => generates {};

package main;
BEGIN { TestApp::Requiring::Regex->new }

require 't/util.pl';

require_ok('Planets::Mercury');
require_ok('Planets::Venus');
require_ok('Planets::Earth');
require_ok('Planets::Mars');
require_ok('Planets::Jupiter');
require_ok('Planets::Saturn');
require_ok('Planets::Uranus');
require_ok('Planets::Neptune');
require_not_ok('Planets::Pluto'); # pluto was a planet when i grew up
