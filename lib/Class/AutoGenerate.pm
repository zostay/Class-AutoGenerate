use strict;
use warnings;

package Class::AutoGenerate;

use Class::AutoGenerate::Declare ();
use Scalar::Util qw/ blessed /;

our $VERSION = 0.01;

=head1 NAME

Class::AutoGenerate - Automatically generate code upon require or use

=head1 SYNOPSIS

  # Create a customized class loader (auto-generator)
  package My::ClassLoader;
  use Class::AutoGenerate -base;

  # Define a matching rule that generates some code...
  requiring 'Some::**::Class' => generates { qq{
      sub print_my_middle_names { print $1,"\n" }
  } };

  # In some other file, let's use the class loader
  package main;

  # Create the class loader, which adds itself to @INC
  use My::ClassLoader;
  BEGIN { My::ClassLoader->new; }

  # These class will be generated on the fly...
  use Some::Freaking::Class;
  use Some::Other::Freaking::Class;

  Some::Freaking::Class->print_my_middle_names;
  Some::Other::Freaking::Class->print_my_middle_names;

  # Output is:
  #   Freaking
  #   Other::Freaking

=head1 DESCRIPTION

B<EXPERIMENTAL.> I'm trying this idea out. Please let me know what you think by contacting me using the information listed under L</AUTHOR>. This is an experiment and any and all aspects of the API are up for revision at this point and I'm not even sure I'll maintain it, but I hope it will be found useful to myself and others.

Sometimes it's nice to be able to generate code on the fly. This tool does just that. You declare a few rules that can be used to define the class names you want to auto-generate and then the code that is to be built from it. Later you create your auto-generator object and start using the auto-generated classes.

This is a generalization baed upon L<Jifty::ClassLoader>. If this experiment is successful in the way I'm testing it out for, it may be used to re-implement that class.

=head1 METHODS

=head2 import

When you are creating a new auto-generating class loader, you will include this statement in your package definition:

  package My::ClassLoader;
  use Class::AutoGenerate -base;

This statement tells L<Class::AutoGenerate> to import all the subroutines in L<Class::AutoGenerate::Declare> into the current package so that a new class loader can be declared.

Later, when you use your class loader, you will use the undecorated form:

  use My::ClassLoader;

In this case, the import method does nothing special.

=cut

sub import {
    my $class = shift;
    my $base  = shift;

    my $package = caller;

    if (defined $base and $base eq '-base') {
        Class::AutoGenerate::Declare->export_to_level(1, undef);
        
        no strict 'refs';
        push @{ $package . '::ISA' }, $class;
        @{ $package . '::RULES' } = ();
    }

    return 1;
}

=head2 new

Creates a new instance of the auto-generating class loader object you've built. The class loader automatically adds itself to the C<@INC> array to start loading classes.

If you want to immediately start using the class loader at compile time, you may wish to call this method within a C<BEGIN> block:

  use My::Custom::ClassLoader;
  BEGIN { My::Custom::ClassLoader->new };

=cut

sub new {
    my $class = shift;

    # Create the class and place ourself into @INC
    my $self = bless {}, $class;
    push @INC, $self;
    return $self;
}

=head2 INC

This is the subroutine called by Perl during a L<perlfunc/require|require> or L<perlfunc/use|use> and evaluates the rules defined in your class loader. See L<perlfunc/require|require> (towards the end) to see how this works.

It should be noted, however, that we cheat the system a little bit. According ot the require hook API, this method should return either a filehandle containing the code to be read or C<undef> indicating that the hook does not know about the file being required. 

This is done, except that only an empty stub package like this is ever returned when a class is auto-generated:

  use strict;
  use warnings;

  package The::Included::Package::Name;

  1;

Instead of having the import mechanism within Perl compile the code, most of the work is handled through symbol table manipulations and code evaluation before the file handle is returned. This allows for some earlier compile-time checking via closures and the like.

=cut

# Use the fully-qualified name since Perl ignores "sub INC" 
# (see perldoc require)
sub Class::AutoGenerate::INC {
    my $self   = shift;
    my $module = shift;

    # Canonicalize $module to :: style rather than / and .pm style
    $module =~ s{\.pm$}{};
    $module =~ s{/}{::}g;

    # Pass off control to _match_and_generate() to do the real work
    return $self->_match_and_generate($module);
}

=head2 _match_and_generate MODULE

This method is used internally to match L<Class::AutoGenerate::Declare/requiring> statements and automatically generate code upon a match.

=cut

sub _match_and_generate {
    my $self   = shift;
    my $module = shift;

    # Get the requiring/generates rules
    my $rules = $self->_rules;
    #use Data::Dumper;
    #$Data::Dumper::Deparse = 1;
    #Test::More::diag(Dumper($rules));

    # Iterate through the rules
    for my $rule (@$rules) {

        # Does it match? First match wins...
        if ($self->_match_requiring($module, $rule->[0])) {
            $self->_autogenerate($module, $rule->[0], $rule->[1]);

            # Return the empty stub to signal class found
            return $self->_stub_file_handle($module);
        }
    }

    # Return undef to signal no such file found
    return undef;
}

=head2 _rules

Used internally to reference the rules declared in the auto-generating class loader.

=cut

sub _rules {
    my $self = shift;
    my $package = blessed $self || $self;

    no strict 'refs';
    return \@{ $package . '::RULES' };
}

=head2 _match_requiring MODULE, PATTERN

Used internally to match a L<Class::AutoGenerate::Declare/requiring> declaration to a package name. Returns true if there's a match, or false otherwise.

=cut

sub _match_requiring {
    my $self    = shift;
    my $module  = shift;
    my $pattern = shift;

    if ($module =~ $pattern) {
        #Test::More::diag("$module matches $pattern");
        return 1;
    }
    else {
        #Test::More::diag("$module misses  $pattern");
        return;
    }
}

=head2 _autogenerate MODULE, PATTERN, GENERATES

This method performs the action of taking the work in the generates declration and stuffing that work into the named package.

=cut

our $package;
sub _autogenerate {
    my $self      = shift;
    my $module    = shift;
    my $pattern   = shift;
    my $generates = shift;

    # match again to setup $1, $2, etc...
    $module =~ $pattern;

    # Setup the $package variable used inside the various declarations
    local $package = $module;

    # Call the code to generate the various codes
    $generates->();
}

=head2 _stub_file_handle MODULE

Returns a basic stub class that is handed off to the import infrastructure of Perl to let it know that we succeeded, even though we already did most of the work for it.

=cut

sub _stub_file_handle {
    my $self   = shift;
    my $module = shift;

    # Here's the stub code...
    my $code = qq{use strict; use warnings; package $module; 1; };

    # Magick that code into a file handle
    open my $fh, '<', \$code;
    return $fh;
}

=head1 SEE ALSO

L<Class::AutoGenerate::Declare>

=head1 AUTHOR

Andrew Sterling Hanenkamp C<< <hanenkamp@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 Boomer Consulting, Inc. All Rights Reserved.

This program is free software and may be modified and distributed under the same terms as Perl itself.

=cut

1;
