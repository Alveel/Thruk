package Thruk::Utils::Auth;

=head1 NAME

Thruk::Utils::Auth - Authorization Utilities for Thruk

=head1 DESCRIPTION

Authorization Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Carp;


##############################################
=head1 METHODS

=cut

##############################################

=head2 get_auth_filter

  my $filter_string = get_auth_filter('hosts');

returns a filter which can be used for authorization

=cut
sub get_auth_filter {
    my $c      = shift;
    my $type   = shift;
    my $strict = shift || 0;

    return("") if $type eq 'status';

    # if authentication is completly disabled
    if($c->config->{'cgi_cfg'}->{'use_authentication'} == 0 and $c->config->{'cgi_cfg'}->{'use_ssl_authentication'} == 0) {
        return("");
    }

    if($strict and $type ne 'hosts' and $type ne 'services') {
        croak("strict authorization not implemented for: ".$type);
    }

    # host authorization
    if($type eq 'hosts') {
        if(!$strict and $c->check_user_roles('authorized_for_all_hosts')) {
            return("");
        }
        return("Filter: contacts >= ".$c->user->get('username'));
    }

    # hostgroups authorization
    elsif($type eq 'hostgroups') {
        return("");
    }

    # service authorization
    elsif($type eq 'services') {
        if(!$strict and $c->check_user_roles('authorized_for_all_services')) {
            return("");
        }
        if(Thruk->config->{'use_strict_host_authorization'}) {
            return("Filter: contacts >= ".$c->user->get('username')."\n");
        } else {
            return("Filter: contacts >= ".$c->user->get('username')."\nFilter: host_contacts >= ".$c->user->get('username')."\nOr: 2");
        }
    }

    # servicegroups authorization
    elsif($type eq 'servicegroups') {
        return("");
    }

    # servicegroups authorization
    elsif($type eq 'timeperiods') {
        return("");
    }

    # comments / downtimes authorization
    elsif($type eq 'comments' or $type eq 'downtimes') {
        my @filter;
        if(!$c->check_user_roles('authorized_for_all_services')) {
            push @filter, "Filter: service_contacts >= ".$c->user->get('username')."\nFilter: service_description !=\nAnd: 2\n";
        }
        if(!$c->check_user_roles('authorized_for_all_hosts')) {
            if(Thruk->config->{'use_strict_host_authorization'}) {
                push @filter, "Filter: host_contacts >= ".$c->user->get('username')."\nFilter: service_description =\nAnd: 2\n";
            } else {
                push @filter, "Filter: host_contacts >= ".$c->user->get('username')."\n";
            }
        }
        return(Thruk::Utils::combine_filter(\@filter, 'Or'));
    }

    # logfile authorization
    elsif($type eq 'log') {
        my @filter;

        # service log entries
        if($c->check_user_roles('authorized_for_all_services')) {
            # allowed for all services related log entries
            push @filter, "Filter: current_service_description != \n";
        }
        else {
            push @filter, "Filter: current_service_contacts >= ".$c->user->get('username')."\nFilter: service_description != \nAnd: 2\n";
        }

        # host log entries
        if($c->check_user_roles('authorized_for_all_hosts')) {
            # allowed for all host related log entries
            push @filter, "Filter: service_description = \nFilter: host_name != \nAnd: 2";
        }
        else {
            if(Thruk->config->{'use_strict_host_authorization'}) {
                # only allowed for the host itself, not the services
                push @filter, "Filter: current_host_contacts >= ".$c->user->get('username')."\nFilter: service_description = \nAnd: 2\n";
            } else {
                # allowed for all hosts and its services
                push @filter, "Filter: current_host_contacts >= ".$c->user->get('username')."\n";
            }
        }

        # other log entries
        if($c->check_user_roles('authorized_for_system_information')) {
            # everything not related to a specific host or service
            push @filter, "Filter: service_description = \nFilter: host_name = \nAnd: 2";
        }

        return(Thruk::Utils::combine_filter(\@filter, 'Or'));
    }

    else {
        croak("type $type not supported");
    }

    croak("cannot authorize query");
    return;
}


1;

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
