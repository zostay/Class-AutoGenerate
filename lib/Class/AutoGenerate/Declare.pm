use strict;
use warnings;

package Class::AutoGenerate::Declare;

require Exporter;

our $VERSION = 0.01;

our @ISA = qw( Exporter );
our @EXPORT = qw(
    requiring generates
    extends uses requires defines
    generate_from source_code source_file
);

use Carp;
use Scalar::Util qw/ reftype /;

=head1 NAME

Class::AutoGenerate::Declare - Declarations for an auto-generating class loader

=head1 SYNOPSIS

  # Create a customized class loader (auto-generator)
  package My::ClassLoader;
  use Class::AutoGenerate -base;

  # Define a matching rule that generates some code...
  requiring 'Some::**::Class' => generates { qq{
      sub print_my_middle_names { print $1,"\n" }
  } };

=head1 DESCRIPTION

B<EXPERIMENTAL.> I'm trying this idea out. Please let me know what you think by contacting me using the information listed under L</AUTHOR>. This is an experiment and any and all aspects of the API are up for revision at this point and I'm not even sure I'll maintain it, but I hope it will be found useful to myself and others.

You do not use this class directly, but it contains the documentation for how to declare a new auto-generating class loader. To use this class, just tell L<Class::AutoGenerate> that you are building a base class:

  package My::ClassLoader;
  use Class::AutoGenerate -base;

This will then import the declarations described here into your class loader so that you can define your auto-generation rules.

=head1 DECLARATIONS

=head2 requiring PATTERN => generates { ... };

The C<requiring> rule tests the pattern against the given package name and runs the C<generates> block if there's a match. The pattern can be any of the following:

=over

=item Package Name

If you provide an exact package name (one containing only letters, numbers, underscores, and colons), then only that exact name will be matched.

For example:

  requiring 'TestApp::Model::Flooble' => ...

would only match when exactly C<TestApp::Model::Flooble> was required or used.

=item Package Glob

If you provide a pattern string containing one or more wildcards, the pattern will match any package matching the wildcard pattern. This is very similar to how file globs work, but we use "::" instead of "/" as our divider. There are three different wildcards available:

=over

=item 1 Single Asterisk (*). A single asterisk will match zero or more characters of a single package name component.

For example:

  requiring '*::Model::*Collection' => ...

will match C<TestApp::Model::Collection> and C<TestApp::Model::FloobleCollection> and C<SomeOtherApp::Model::WakkaCollection>. 

=item 1 Double Asterisk (**). A double asterisk will match zero or more chaters of a package name, possibly spanning multiple double-colon (::) separators.

For example:

  requiring '**::Model::**Collection' => ...

will match C<TestApp::Plugin::Charts::Model::Deep::Model::NameCollection> and C<TestApp::Model::FloobleCollection> and C<SomeOtherApp::Model::Collection>.

=item 1 Question mark (?). A question mark will match exactly one character in a package name.

For example:

  requiring 'TestApp??::Record' => ...

will match C<TestAppAA::Record> and C<TestApp12::Record>.

=back

Each occurrence of a wildcard will be captured for use in the L</generates> block. The first wildcard will be C<$1>, the second C<$2>, etc.

For example:

  requiring 'TestApp??::**::*' => ...

would match C<TestApp38::A::Package::Name::Blah> and would have the following values available in C<generates>:

  $1 = '3';
  $2 = '8';
  $3 = 'A::Package::Name';
  $4 = 'Blah';

=item Regular Expression

You may use a regular expression to match anything more complicated than this. (In fact, the previous matching mechanism are converted to regular expressions, but are convenient for handling the common cases.)

For example:

  requiring qr/^(.*)::(\w+)::(\w+)(\d{2})$/ => ...

Any captures performed in the regular expression will be available as C<$1>, C<$2>, etc. in the L</generates> block.

=item Array of Matches

Finally, you may also place a series of matches into an array. The given generates block will be used if any of the matches match a given module name.

  requiring [ 'App', 'App::**', qr/^SomeOther::(Thing|Whatsit)$/ ] => ...

=back

=cut

sub _compile_glob_pattern($) {
    my $glob = shift;

    # If it's a regexp, we don't want to compile it as if it's a glob!
    return $glob if ref $glob and ref $glob eq 'Regexp';

    # The following code was adapted from Jifty::Dispatcher of trunk r2520
    
    # Escape and normalize
    $glob = quotemeta($glob);
    $glob =~ s{(?:\\:)(?:\\:)}{::}g;

    # Check to see if they have any glob wildcards
    my $has_capture = ( $glob =~ / \\ [\*\?] /x );
    if ($has_capture) {

        # Double-asterisk will match anything
        $glob =~ s{ \\ \* \\ \* }{([\\w:]*)}gx;

        # Single-asterisk will match any number of characters, but not colons
        $glob =~ s{ \\ \* }{(\\w*)}gx;

        # Single-question mark  will match a single character, but not colons
        $glob =~ s{ \\ \? }{(\\w)}gx

    }

    # If they haven't asked ot capture anything in particular, capture all
    else {
        $glob = "($glob)";
    }

    # Make a regexp
    return qr{^$glob$};
}

sub _register_rules($$$) {
    my $class   = shift;
    my $pattern = shift;
    my $code    = shift;

    # If an array, push the generates code for each pattern
    if (ref $pattern and reftype $pattern eq 'ARRAY') {
        &_register_rules($class, $_, $code) foreach @$pattern;
    }

    # Otherwise, compile globs and push in the pattern => code rule thingies
    else {
        $pattern = _compile_glob_pattern $pattern;
        push @{ $class->_rules }, [ $pattern => $code ];
    }
}

sub requiring($$) {
    my $pattern = shift;
    my $code    = shift;

    # Register a new rule (or rules) for the caller
    my $package = caller;
    _register_rules $package, $pattern, $code;
}

=head2 generates { ... }

This handles the second half of the requiring/generates statement. The code block may contain any code you need, but you'll probably want it to contain statements for generating code to go into the required class.

  requiring 'My::*' => generates {
      my $name = $1;

      extends "My::Base::$name";

      uses 'Scalar::Util', 'looks_like_number';

      defines '$scalar' => 14;
      defines '@array'  => [ 1, 2, 3 ];
      defines '%hash'   => { x => 1, y => 2 };

      defines 'package_name' => sub { $package };
      defines 'short_name'   => sub { $name };
  };

If we included the rule above, intantiated the class loader, and then ran:

  use My::Flipper;

A class would be generated named C<My::Flipper> that uses C<My::Base::Flipper> as its only base class, imports the C<looks_like_number> function from L<Scalar::Util>, defines a scalar package variable C<$scalar> set to 14, an array package variable, C<@array>, set to C<(1, 2, 3)>, a hash package variable named C<%hash> set to C<(x => 1, y => 2)>, and two subroutines named C<package_name> and C<short_name>.

=cut

sub generates(&) { shift }

=head2 extends CLASSES

This subroutine is used with L</generates> to mark the generated class as extending the named class or classes. This pushes the named classes into the C<@ISA> array for the class when it is generated.

=cut

sub extends(@) {
    no strict 'refs';
    push @{ $Class::AutoGenerate::package . '::ISA' }, @_;
}

=head2 uses CLASS, ARGS

This subroutine states that the generated class uses another package. The first argument is the class to use and the remaining arguments are passed to the import method of the used class (the first argument may also be a version number, see L<perlfunc/use>).

=cut

sub uses($;@) {
    my $class = shift;
    my $args = join ', ', map { "'".quotemeta($_)."'" } @_;
    $args = " ($args)" if $args;

    eval "package $Class::AutoGenerate::package; use $class$args;";
    die $@ if $@;
}

=head2 requires EXPR

This is similar to L</uses>, but uses L<perlfunc/require> instead of C<use>.

=cut

sub requires($) {
    my $expr  = shift;

    # Make a nice string unless it's barewordable... this might not always do
    # the right thing...
    $expr = '"' . quotemeta($expr) . '"' unless $expr =~ /^[\w:]+$/;

    eval "package $Class::AutoGenerate::package; require $expr;";
    die $@ if $@;
}

=head2 defines NAME => VALUE

This is the general purpose definition declaration. If the given name starts with a dollar sign ($), then a scalar value is created. If the given name starts with an at sign (@), then an array value is added to the class. If the given starts with a percent sign (%), then a hash value will be generated. Finally, if it starts with a letter, underscore, or ampersand (&), a subroutine is added to the package.

The given value must be appropriate for the type of definition being generated.

=cut

sub defines($$) {
    my $name  = shift;
    my $value = shift;

    # It's a scalar
    if ($name =~ s/^\$//) {
        no strict 'refs';
        ${ $Class::AutoGenerate::package . '::' . $name } = $value;
    }

    # It's an array
    elsif ($name =~ s/^\@//) {
        no strict 'refs';
        @{ $Class::AutoGenerate::package . '::' . $name } = @$value;
    }

    # It's a hash
    elsif ($name =~ s/^\%//) {
        no strict 'refs';
        %{ $Class::AutoGenerate::package . '::' . $name } = %$value;
    }

    # It's a method
    else {
        $name =~ s/^\&//;

        no strict 'refs';
        *{ $Class::AutoGenerate::package . '::' . $name } = $value;
    }
}

=head2 generate_from SOURCE

If you need to inject code directly into the package generated, this is the general purpose way to do it. Just pass a string (or use one of the helpers L</source_file> or L</source_file> below) and that code will be evaluated within the new package.

  requiring 'Some::Class' => generates {
      extends 'Class::Access::Fast';

      generate_from source_code qq{

          __PACKAGE__->mk_accessors( qw/ name title description / );

      };
  };

B<Caution:> If user input has any effect on the code generated, you should make certain that all input is carefully validated to prevent code injection.

=cut

sub generate_from($) {
    my $source_code = shift;

    eval "package $Class::AutoGenerate::package; $source_code";
    die $@ if $@;
}

=head2 source_code SOURCE

This method is purely for use with making your code a little easier to read. It doesn't do anything but return the argument passed to it.

=cut

sub source_code($) { shift }

=head2 source_file FILENAME

Given a file name, this evalutes the Perl in that file within the context of the package.

  requiring 'Another::Class' => generates {
      generate_from source_file 'code_base.pl';
  };

=cut

sub source_file($) {
    my $filename = shift;

    # Open the file...
    open my $fh, '<', $filename or die "failed to open $filename: $!";

    # Slurp it down...
    local $/;
    return <$fh>;
}

=head1 AUTHOR

Andrew Sterling Hanenkamp C<< <hanenkamp@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 Boomer Consulting, Inc.

This program is free software and may be modified and distributed under the same terms as Perl itself.

=cut

1;
