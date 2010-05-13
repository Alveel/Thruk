use strict;
use warnings;
use Time::HiRes qw(sleep);
use Test::WWW::Selenium;
use Test::More "no_plan";
use Test::Exception;

my $url     = $ENV{SELENIUM_TEST_URL}     || "http://localhost:3000/";
my $browser = $ENV{SELENIUM_TEST_BROWSER} || "*firefox";
my $host    = $ENV{SELENIUM_TEST_HOST}    || "localhost";
my $port    = $ENV{SELENIUM_TEST_PORT}    || "4444";
my $sel = Test::WWW::Selenium->new( host        => $host,
                                    port        => $port, 
                                    browser     => $browser,
                                    browser_url => $url
                                  );

$sel->open_ok("/");
$sel->click_ok("link=Hosts");
$sel->wait_for_page_to_load_ok("30000");
$sel->title_is("Current Network Status");
$sel->click_ok("//tr[\@id='r1']/td[3]");
$sel->value_is("multi_cmd_submit_button", "submit command for 1 host");
$sel->click_ok("//tr[\@id='r2']/td[3]");
$sel->value_is("multi_cmd_submit_button", "submit command for 2 hosts");
$sel->click_ok("//tr[\@id='r3']/td[3]");
$sel->value_is("multi_cmd_submit_button", "submit command for 3 hosts");
$sel->click_ok("//tr[\@id='r3']/td[4]");
$sel->value_is("multi_cmd_submit_button", "submit command for 2 hosts");
$sel->click_ok("opt1");
$sel->click_ok("multi_cmd_submit_button");
$sel->wait_for_page_to_load_ok("30000");
$sel->title_is("Current Network Status");
$sel->is_text_present_ok("Commands successfully submitted");
