package Thruk::Controller::reports2;

use strict;
use warnings;
use Module::Load qw/load/;
use Mojo::Base 'Mojolicious::Controller';

=head1 NAME

Thruk::Controller::reports2 - Mojolicious Controller

=head1 DESCRIPTION

Mojolicious Controller.

=head1 METHODS

=cut

##########################################################

=head2 add_routes

page: /thruk/cgi-bin/reports2.cgi

=cut

sub add_routes {
    my($self, $app, $r) = @_;
    $r->any('/*/cgi-bin/reports2.cgi')->to(controller => 'Controller::reports2', action => 'index');

    Thruk::Utils::Menu::insert_item('Reports', {
                                    'href'  => '/thruk/cgi-bin/reports2.cgi',
                                    'name'  => 'Reporting',
    });

    # enable reporting features if this plugin is loaded
    $app->config->{'use_feature_reports'} = 'reports2.cgi';

    return;
}

##########################################################

=head2 index

=cut
sub index {
    my ( $c ) = @_;

    Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_CACHED_DEFAULTS);

    if(!$c->config->{'reports2_modules_loaded'}) {
        load Carp, qw/confess carp/;
        load Thruk::Utils::Reports;
        load Thruk::Utils::Avail;
        $c->config->{'reports2_modules_loaded'} = 1;
    }

    $c->stash->{'no_auto_reload'}      = 1;
    $c->stash->{title}                 = 'Reports';
    $c->stash->{page}                  = 'status'; # otherwise we would have to create a reports.css for every theme
    $c->stash->{_template}             = 'reports.tt';
    $c->stash->{subtitle}              = 'Reports';
    $c->stash->{infoBoxTitle}          = 'Reporting';
    $c->stash->{has_jquery_ui}         = 1;
    $c->stash->{'wkhtmltopdf'}         = 1;
    $c->stash->{'disable_backspace'}   = 1;

    $Thruk::Utils::CLI::c              = $c;

    my $report_nr = $c->{'request'}->{'parameters'}->{'report'};
    my $action    = $c->{'request'}->{'parameters'}->{'action'}    || 'show';
    my $highlight = $c->{'request'}->{'parameters'}->{'highlight'} || '';
    my $refresh   = 0;
    $refresh = $c->{'request'}->{'parameters'}->{'refresh'} if exists $c->{'request'}->{'parameters'}->{'refresh'};

    if(ref $action eq 'ARRAY') { $action = pop @{$action}; }

    if($action eq 'updatecron') {
        if(Thruk::Utils::Reports::update_cron_file($c)) {
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'updated crontab' });
        } else {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'failed to update crontab' });
        }
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi");
    }

    if($action eq 'check_affected_objects') {
        $c->{'request'}->{'parameters'}->{'get_total_numbers_only'} = 1;
        my @res;
        my $backends = $c->{'request'}->{'parameters'}->{'backends'} || $c->{'request'}->{'parameters'}->{'backends[]'};
        my $template = $c->{'request'}->{'parameters'}->{'template'};
        my $sub;
        if($template) {
            eval {
                $sub = Thruk::Utils::get_template_variable($c, 'reports/'.$template, 'affected_sla_objects', { block => 'edit' }, 1);
            };
        }
        $sub = 'Thruk::Utils::Avail::calculate_availability' unless $sub;
        if($backends and ($c->{'request'}->{'parameters'}->{'backends_toggle'} or $c->{'request'}->{'parameters'}->{'report_backends_toggle'})) {
            $c->{'db'}->disable_backends();
            $c->{'db'}->enable_backends($backends);
        }
        if($c->{'request'}->{'parameters'}->{'param'}) {
            for my $str (split/&/mx, $c->{'request'}->{'parameters'}->{'param'}) {
                my($key,$val) = split(/=/mx, $str, 2);
                if($key =~ s/^params\.//mx) {
                    $c->{'request'}->{'parameters'}->{$key} = $val unless exists $c->{'request'}->{'parameters'}->{$key};
                }
            }
        }
        eval {
            $Thruk::Utils::Reports::Render::c = $c;
            eval {
                require Thruk::Utils::Reports::CustomRender;
            };
            @res = &{\&{$sub}}($c);
        };
        my $json;
        if($@ or scalar @res == 0) {
            $json        = { 'hosts' => 0, 'services' => 0, 'error' => $@ };
        } else {
            my $total    = $res[0] + $res[1];
            my $too_many = $total > $c->config->{'report_max_objects'} ? 1 : 0;
            $json        = { 'hosts' => $res[0], 'services' => $res[1], 'too_many' => $too_many };
        }
        return $c->render(json => $json);
    }

    if(defined $report_nr) {
        if($report_nr !~ m/^\d+$/mx and $report_nr ne 'new') {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'invalid report number: '.$report_nr });
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi");
        }
        if($action eq 'show') {
            if(!Thruk::Utils::Reports::report_show($c, $report_nr, $refresh)) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
            }
        }
        elsif($action eq 'edit') {
            return report_edit($c, $report_nr);
        }
        elsif($action eq 'edit2') {
            return report_edit_step2($c, $report_nr);
        }
        elsif($action eq 'update') {
            return report_update($c, $report_nr);
        }
        elsif($action eq 'save') {
            return report_save($c, $report_nr);
        }
        elsif($action eq 'remove') {
            return report_remove($c, $report_nr);
        }
        elsif($action eq 'cancel') {
            return report_cancel($c, $report_nr);
        }
        elsif($action eq 'email') {
            return report_email($c, $report_nr);
        }
        elsif($action eq 'profile') {
            return report_profile($c, $report_nr);
        }
    }

    if($c->config->{'Thruk::Plugin::Reports2'}->{'wkhtmltopdf'} and !-x $c->config->{'Thruk::Plugin::Reports2'}->{'wkhtmltopdf'}) {
        $c->stash->{'wkhtmltopdf'} = 0;
        $c->stash->{'wkhtmltopdf_file'} = $c->config->{'Thruk::Plugin::Reports2'}->{'wkhtmltopdf'};
    }

    # show list of configured reports
    $c->stash->{'no_auto_reload'} = 0;
    $c->stash->{'highlight'}      = $highlight;
    $c->stash->{'reports'}        = Thruk::Utils::Reports::get_report_list($c);

    Thruk::Utils::ssi_include($c);

    return 1;
}

##########################################################

=head2 report_edit

=cut
sub report_edit {
    my($c, $report_nr) = @_;

    my $r;
    $c->stash->{'params'} = {};
    if($report_nr eq 'new') {
        $r = Thruk::Utils::Reports::_get_new_report($c);
        # set currently enabled backends
        $r->{'backends'} = [];
        for my $b (keys %{$c->stash->{'backend_detail'}}) {
            push @{$r->{'backends'}}, $b if $c->stash->{'backend_detail'}->{$b}->{'disabled'} == 0;
        }
        for my $key (keys %{$c->{'request'}->{'parameters'}}) {
            if($key =~ m/^params\.(.*)$/mx) {
                $c->stash->{'params'}->{$1} = $c->{'request'}->{'parameters'}->{$key};
            } else {
                $r->{$key} = $c->{'request'}->{'parameters'}->{$key} if defined $c->{'request'}->{'parameters'}->{$key};
            }
        }
        $r->{'template'} = $c->{'request'}->{'parameters'}->{'template'} || $c->config->{'Thruk::Plugin::Reports2'}->{'default_template'} || 'sla_host.tt';
        if($c->{'request'}->{'parameters'}->{'params.url'}) {
            $r->{'params'}->{'url'} = $c->{'request'}->{'parameters'}->{'params.url'};
        }
    } else {
        $r = Thruk::Utils::Reports::_read_report_file($c, $report_nr);
        if(!defined $r or $r->{'readonly'}) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'cannot change report' });
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi");
        }
    }

    $c->stash->{templates} = Thruk::Utils::Reports::get_report_templates($c);
    _set_report_data($c, $r);

    Thruk::Utils::ssi_include($c);
    $c->stash->{_template} = 'reports_edit.tt';
    return;
}

##########################################################

=head2 report_edit_step2

=cut
sub report_edit_step2 {
    my($c, $report_nr) = @_;

    my $r;
    if($report_nr eq 'new') {
        $r = Thruk::Utils::Reports::_get_new_report($c);
    } else {
        $r = Thruk::Utils::Reports::_read_report_file($c, $report_nr);
        if(!defined $r or $r->{'readonly'}) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'cannot change report' });
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi");
        }
    }

    my $template     = $c->{'request'}->{'parameters'}->{'template'};
    $r->{'template'} = $template if defined $template;

    _set_report_data($c, $r);

    $c->stash->{_template} = 'reports_edit_step2.tt';
    return;
}


##########################################################

=head2 report_save

=cut
sub report_save {
    my($c, $report_nr) = @_;

    return unless Thruk::Utils::check_csrf($c);

    my $params = $c->{'request'}->{'parameters'};
    $params->{'params.t1'} = Thruk::Utils::parse_date($c, $params->{'t1'}) if defined $params->{'t1'};
    $params->{'params.t2'} = Thruk::Utils::parse_date($c, $params->{'t2'}) if defined $params->{'t2'};

    my($data) = Thruk::Utils::Reports::get_report_data_from_param($params);
    my $msg = 'report updated';
    if($report_nr eq 'new') { $msg = 'report created'; }
    my $report;
    if($report = Thruk::Utils::Reports::report_save($c, $report_nr, $data)) {
        if(Thruk::Utils::Reports::update_cron_file($c)) {
            if(defined $report->{'var'}->{'opt_errors'}) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => "Error in Report Options:<br>".join("<br>", @{$report->{'var'}->{'opt_errors'}}) });
            } else {
                Thruk::Utils::set_message( $c, { style => 'success_message', msg => $msg });
            }
        }
    } else {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
    }
    return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi?highlight=".$report_nr);
}

##########################################################

=head2 report_update

=cut
sub report_update {
    my($c, $report_nr) = @_;

    my $report = Thruk::Utils::Reports::_read_report_file($c, $report_nr);
    if($report) {
        Thruk::Utils::Reports::generate_report_background($c, $report_nr, undef, $report);
        Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'report scheduled for update' });
    } else {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
    }
    return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi");
}

##########################################################

=head2 report_remove

=cut
sub report_remove {
    my($c, $report_nr) = @_;

    return unless Thruk::Utils::check_csrf($c);

    if(Thruk::Utils::Reports::report_remove($c, $report_nr)) {
        Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'report removed' });
    } else {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
    }
    return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi");
}

##########################################################

=head2 report_cancel

=cut
sub report_cancel {
    my($c, $report_nr) = @_;

    my $report = Thruk::Utils::Reports::_read_report_file($c, $report_nr);
    if($report) {
        if($report->{'var'}->{'is_waiting'}) {
            Thruk::Utils::Reports::set_running($c, $report_nr, 0);
            Thruk::Utils::Reports::set_waiting($c, $report_nr, 0, 0);
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'report canceled' });
        }
        elsif($report->{'var'}->{'job'}) {
            Thruk::Utils::External::cancel($c, $report->{'var'}->{'job'});
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'report canceled' });
        } else {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'report could not be canceled' });
        }
    } else {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
    }
    return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi");
}

##########################################################

=head2 report_profile

=cut
sub report_profile {
    my($c, $report_nr) = @_;

    my $data = '';
    my $report = Thruk::Utils::Reports::_read_report_file($c, $report_nr);
    if($report) {
        if($report->{'var'}->{'profile'}) {
            $data = $report->{'var'}->{'profile'};
        } else {
            $data = "no profile information available";
        }
    } else {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such report', code => 404 });
    }
    my $json = { 'data' => $data };
    return $c->render(json => $json);
}

##########################################################

=head2 report_email

=cut
sub report_email {
    my($c, $report_nr) = @_;

    my $r = Thruk::Utils::Reports::_read_report_file($c, $report_nr);
    if(!defined $r) {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'report does not exist' });
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi");
    }

    if($c->{'request'}->{'parameters'}->{'send'}) {
        return unless Thruk::Utils::check_csrf($c);
        my $to      = $c->{'request'}->{'parameters'}->{'to'}      || '';
        my $cc      = $c->{'request'}->{'parameters'}->{'cc'}      || '';
        my $desc    = $c->{'request'}->{'parameters'}->{'desc'}    || '';
        my $subject = $c->{'request'}->{'parameters'}->{'subject'} || '';
        if($to) {
            Thruk::Utils::Reports::report_send($c, $report_nr, 1, $to, $cc, $subject, $desc);
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'report successfully sent by e-mail' });
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/reports2.cgi?highlight=".$report_nr);
        }
        Thruk::Utils::set_message( $c, { style => 'success_message', msg => '\'to\' address missing' });
    }

    $c->stash->{size}    = -s $c->config->{'tmp_path'}.'/reports/'.$r->{'nr'}.'.dat';
    if($r->{'var'}->{'attachment'} && (!$r->{'var'}->{'ctype'} || $r->{'var'}->{'ctype'} ne 'html2pdf')) {
        $c->stash->{attach}  = $r->{'var'}->{'attachment'};
    } else {
        $c->stash->{attach}  = 'report.pdf';
    }
    $c->stash->{subject} = $r->{'subject'} || 'Report: '.$r->{'name'};
    $c->stash->{r}       = $r;

    Thruk::Utils::ssi_include($c);
    $c->stash->{_template} = 'reports_email.tt';
    return;
}

##########################################################
sub _set_report_data {
    my($c, $r) = @_;

    $c->stash->{'t1'} = $r->{'params'}->{'t1'} || time() - 86400;
    $c->stash->{'t2'} = $r->{'params'}->{'t2'} || time();
    $c->stash->{'t1'} = $c->stash->{'t1'} - $c->stash->{'t1'}%60;
    $c->stash->{'t2'} = $c->stash->{'t2'} - $c->stash->{'t2'}%60;

    $c->stash->{r}           = $r;
    $c->stash->{timeperiods} = $c->{'db'}->get_timeperiods(filter => [Thruk::Utils::Auth::get_auth_filter($c, 'timeperiods')], remove_duplicates => 1, sort => 'name');
    $c->stash->{languages}   = Thruk::Utils::Reports::get_report_languages($c);

    Thruk::Utils::Reports::add_report_defaults($c, undef, $r);

    return;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
