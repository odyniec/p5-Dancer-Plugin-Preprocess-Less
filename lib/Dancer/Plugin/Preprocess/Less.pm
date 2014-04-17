package Dancer::Plugin::Preprocess::Less;

use strict;
use warnings;

# ABSTRACT: Generate CSS files from .less files

# VERSION

use CSS::LESSp;

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

=head1 SEE ALSO

=for :list

* L<http://lesscss.org/> - Less website

* L<CSS::LESSp>

=head1 ACKNOWLEDGEMENTS

The plugin uses Ivan Drinchev's L<CSS::LESSp> module. 

=cut
