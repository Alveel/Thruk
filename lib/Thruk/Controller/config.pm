package Thruk::Controller::config;

use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';

=head1 NAME

Thruk::Controller::config - Mojolicious Controller

=head1 DESCRIPTION

Mojolicious Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index {
    my ( $c ) = @_;

    Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_CACHED_DEFAULTS);

    $c->stash->{title}            = 'Configuration';
    $c->stash->{infoBoxTitle}     = 'Configuration';
    $c->stash->{page}             = 'config';
    $c->stash->{_template}        = 'config.tt';
    $c->stash->{'no_auto_reload'} = 1;

    return $c->detach('/error/index/8') unless $c->check_user_roles( "authorized_for_configuration_information" );

    my $type = $c->{'request'}->{'parameters'}->{'type'};
    $c->stash->{type}             = $type;
    return unless defined $type;

    # timeperiods
    if($type eq 'timeperiods') {
        $c->{'db'}->get_timeperiods(sort => 'name', remove_duplicates => 1, pager => 1);
        $c->stash->{_template} = 'config_timeperiods.tt';
    }

    # commands
    if($type eq 'commands') {
        $c->{'db'}->get_commands(sort => 'name', remove_duplicates => 1, pager => 1);
        $c->stash->{_template} = 'config_commands.tt';
    }

    # contacts
    elsif($type eq 'contacts') {
        $c->{'db'}->get_contacts(sort => 'name', remove_duplicates => 1, pager => 1);
        $c->stash->{_template} = 'config_contacts.tt';
    }

    # contactgroups
    elsif($type eq 'contactgroups') {
        $c->{'db'}->get_contactgroups(sort => 'name', remove_duplicates => 1, pager => 1);
        $c->stash->{_template} = 'config_contactgroups.tt';
    }

    # hosts
    elsif($type eq 'hosts') {
        my $filter;
        if(defined $c->{'request'}->{'parameters'}->{'jump2'}) {
            $filter = [ { 'name' => $c->{'request'}->{'parameters'}->{'jump2'} } ];
        }
        $c->{'db'}->get_hosts(sort => 'name', remove_duplicates => 1, pager => 1, extra_columns => ['contacts'], filter => $filter );
        $c->stash->{_template} = 'config_hosts.tt';
    }

    # services
    elsif($type eq 'services') {
        my $filter;
        if( defined $c->{'request'}->{'parameters'}->{'jump2'} and defined $c->{'request'}->{'parameters'}->{'jump3'} ) {
            $filter = [ { 'host_name' => $c->{'request'}->{'parameters'}->{'jump2'}, 'description' => $c->{'request'}->{'parameters'}->{'jump3'} } ];
        }
        $c->{'db'}->get_services(sort => [ 'host_name', 'description' ], remove_duplicates => 1, pager => 1, extra_columns => ['contacts'], filter => $filter);
        $c->stash->{_template} = 'config_services.tt';
    }

    # hostgroups
    elsif($type eq 'hostgroups') {
        $c->{'db'}->get_hostgroups(sort => 'name', pager => 1);
        $c->stash->{_template} = 'config_hostgroups.tt';
    }

    # servicegroups
    elsif($type eq 'servicegroups') {
        $c->{'db'}->get_servicegroups(sort => 'name', pager => 1);
        $c->stash->{_template} = 'config_servicegroups.tt';
    }

    $c->stash->{jump} = $c->{'request'}->{'parameters'}->{'jump'} || '';

    return 1;
}


=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
