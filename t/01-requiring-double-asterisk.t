#!/usr/bin/env perl
use strict;
use warnings;

use Test::More tests => 10;

package TestApp::Requiring::DoubleAsterisk;
use Class::AutoGenerate -base;

requiring 'TestApp::**' => generates {};
requiring '**::Auto'    => generates {};

package main;
BEGIN { TestApp::Requiring::DoubleAsterisk->new }

require 't/util.pl';

require_ok('TestApp::Delta');
require_ok('TestApp::Columbia');
require_ok('TestApp::Vostok');

require_not_ok('Snoopy::Delta');
require_ok('TestApp::Snoopy::Columbia');
require_not_ok('Snoopy::Vostok');

require_ok('Redstone::Auto');
require_ok('EdWhite::Auto');

require_ok('Delta7::TestApp::Auto');

require_ok('TestApp::Auto');
