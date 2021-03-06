package MediaWords::Controller::Admin::CM;
use Modern::Perl "2015";
use MediaWords::CommonLibs;

use strict;
use warnings;
use base 'Catalyst::Controller';

=head1 NAME>

MediaWords::Controller::Admin::CM

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub index : Local
{
    my ( $self, $c ) = @_;

    return $self->index( $c );
}

sub list : Local
{
    my ( $self, $c ) = @_;

    $c->res->redirect( $c->uri_for( '/admin/tm/list' ) );
}

1;
