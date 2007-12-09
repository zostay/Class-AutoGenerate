#!/usr/bin/env perl
use strict;
use warnings;

use Test::More tests => 9;

package TestApp::Requiring::Regex;
use Class::AutoGenerate -base;

requiring qr/^TestApp::(\w+)$/ => generates {};
requiring qr/^\w\d+::Auto$/    => generates {};

package main;
BEGIN { TestApp::Requiring::Regex->new }

require 't/util.pl';

require_ok('TestApp::Delta');
require_ok('TestApp::Columbia');
require_ok('TestApp::Vostok');

require_not_ok('Snoopy::Delta');
require_not_ok('TestApp::Snoopy::Columbia');
require_not_ok('Snoopy::Vostok');

require_ok('R1234::Auto');
require_ok('E8::Auto');

require_not_ok('XYZ::Auto');
