package Dancer::Plugin::Preprocess::Less;

use strict;
use warnings;

# ABSTRACT: Generate CSS files from .less files

# VERSION

use CSS::LESSp;
use Cwd 'abs_path';
use Dancer ':syntax';
use Dancer::Plugin;
use File::Spec::Functions qw(catfile);

my $settings = plugin_setting;
my $paths;

my $public_dir = abs_path(setting('public') || '');

if (exists $settings->{paths}) {
    $paths = $settings->{paths};
}
else {
    $paths = ['css'];
}

# Translate URL paths to filesystem paths
my @fs_paths = map { catfile(split('/'), "") } @$paths;

if ($settings->{save}) {
    # Check if the directories are writable
    for my $path (@fs_paths) {
        my $full_path = catfile($public_dir, $path);
        if (!-w $full_path) {
            warning __PACKAGE__ . ": Can't write to $full_path";
        }
    }
}

# Make a regular expression to match URL paths
my $paths_re = join '|', map {
    my $s = $_;
    $s =~ s{^[^/]}{/$&};    # Add leading slash, if missing
    $s =~ s{/$}{};          # Remove trailing slash
    quotemeta $s;
} reverse sort @$paths;

sub _process_less_file {
    my $less_file = shift;
    
    open (my $f, '<', $less_file);
    my $contents;
    {
        local $/;
        $contents = <$f>;
    }
    close($f);
    
    return join '', CSS::LESSp->parse($contents);
}

hook before_file_render => sub {
    # If saving is not enabled, then there's nothing for us to do (since we
    # won't be able to save the generated CSS rules in a file, duh)
    return if !$settings->{save};

    my $path = abs_path(shift);
    
    # Build a regular expression to match filesystem paths
    my $fs_paths_re = join '|', map { quotemeta } @fs_paths;
    
    my $path_re = '^' . quotemeta(catfile($public_dir, "")) .
        '(?:' . $fs_paths_re . ')';

    if ($path =~ qr{$path_re} && $path =~ qr{\.css$}) {
        (my $input_file = $path) =~ s/\.css$/.less/;

        if (-f $input_file && (stat($path))[9] < (stat($input_file))[9]) {
            # There is a Less file newer than the CSS file
            my $css = _process_less_file($input_file);
            
            if (defined $css) {
                # Save the generated CSS data
                open(my $f, '>', $path);
                print {$f} $css;
                close($f);
            }
        }
    }    
};

get qr{($paths_re)/([^/]*\.css)} => sub {
    my ($path, $css_file) = splat;

    # Prepend the path to the CSS file name
    $path = catfile(split('/', $path));
    $css_file = catfile($path, $css_file);
    
    # Prepend public directory location
    my $css_file_abs = catfile($public_dir, $css_file);
    
    (my $input_file = $css_file_abs) =~ s/\.css$/.less/;

    if (-f $input_file) {
        # Less file exists
        my $css = _process_less_file($input_file);
        
        if ($settings->{save}) {
            # Saving enabled -- save the generated CSS as the requested file
            open(my $f, '>', $css_file_abs);
            print {$f} $css;
            close($f);
        }
        
        header 'content-type' => 'text/css';
        return $css;
    }
    else {
        # Check if the CSS file exists. Probably not, because if it does exist,
        # then Dancer should have already served it as a static file, and we
        # shouldn't even end up in this route handler. Still, we'll do this
        # check in case we're in some wacky parallel universe where route
        # handlers are run before static files.
        if (-f $css_file_abs) {
            return send_file($css_file);
        }
        else {
            return send_error("Not found", 404);
        }
    }
};

register_plugin;

1;

__END__

=head1 SYNOPSIS

Dancer::Plugin::Preprocess::LESS automatically generates CSS files from Less
files in a Dancer web application.

Add the plugin to your application:

    use Dancer::Plugin::Preprocess::Less;

Configure its settings in the YAML configuration file:

    plugins:
      "Preprocess::Less":
        save: 1
        paths:
          - css
          - subdir/css

=head1 DESCRIPTION

Dancer::Plugin::Preprocess::Less adds support for Less files in a Dancer web
application.

When a request is received for a CSS file, the plugin looks for a Less file with
the same name, and transforms it into CSS. The generated CSS file may then be
saved and served as a regular static file. Every time the source Less file gets
modified, the corresponding CSS file is regenerated.

=head1 CONFIGURATION

The available configuration settings are described below.

=head2 save

If set to C<0>, then the CSS files are generated on-the-fly with every request.
If set to C<1>, the files are generated once and saved, then served as static
files later on.

CSS files are saved in the same directory as the Less files, so the system user
that the web application is running as must be allowed to write to that
directory.

Default: C<0>

=head2 paths

A list of paths to serve CSS files from. Each path is relative to the C<public>
directory of the application.

    plugins:
      "Preprocess::Less":
        paths:
          - css
          - subdir/css

Default: C<'css'>

=head1 SEE ALSO

=for :list

* L<http://lesscss.org/> - Less website

* L<CSS::LESSp>

=head1 ACKNOWLEDGEMENTS

The plugin uses Ivan Drinchev's L<CSS::LESSp> module. 

=cut
