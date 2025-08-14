package Koha::Plugin::Com::ByWaterSolutions::LibraryIQ;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use C4::Auth;
use C4::Context;

use JSON qw( decode_json );

## Here we set our plugin version
our $VERSION         = "{VERSION}";
our $MINIMUM_VERSION = "24.05.00";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Library IQ',
    author          => 'Kyle M Hall',
    date_authored   => '2025-03-08',
    date_updated    => "1900-01-01",
    minimum_version => $MINIMUM_VERSION,
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin adds APIs needed for integration with LibraryIQ',
};

sub new {
    my ($class, $args) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

sub install() {
    my ($self, $args) = @_;

    C4::Context->dbh->do(q{
        ALTER TABLE `statistics`
          ADD KEY `idx_liq_borrowernumber` (`borrowernumber`),
          ADD KEY `idx_liq_itemnumber` (`itemnumber`),
          ADD KEY `idx_liq_stats_borrower_type_date` (`borrowernumber`,`type`,`datetime`);
    });

    return 1;
}

sub upgrade {
    my ($self, $args) = @_;

    C4::Context->dbh->do(q{
        ALTER TABLE `statistics`
          ADD KEY `idx_liq_borrowernumber` (`borrowernumber`),
          ADD KEY `idx_liq_itemnumber` (`itemnumber`),
          ADD KEY `idx_liq_stats_borrower_type_date` (`borrowernumber`,`type`,`datetime`);
    });

    return 1;
}

sub uninstall() {
    my ($self, $args) = @_;

    return 1;
}

sub api_routes {
    my ($self, $args) = @_;

    my $spec_str = $self->mbf_read('openapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub api_namespace {
    my ($self) = @_;

    return 'libraryiq';
}

1;
