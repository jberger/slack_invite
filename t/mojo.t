use Mojo::Base -strict;

use Mojo::File 'path';
use Test::More;
use Test::Mojo;

# for mock service
use Mojolicious;

my $script = path(__FILE__)->dirname->sibling('mojo.pl');

# testing instance with app and injected config
my $t = Test::Mojo->new($script => {
  slack_api_token => 'API-TOKEN',
  slack_channels => 'FOO,BAR,BAZ',
  slack_api_url => '/invite',
});

# mock slack api service attached to app's ua
our ($slack_form, $mock_res, @log);
my $mock = Mojolicious->new;
$mock->routes->post('/invite' => sub {
  my $c = shift;
  $slack_form = $c->req->params->to_hash;
  $c->render(json => $mock_res);
});
$t->app->ua->server->app($mock);

# replace logger with one that appends to @log
my $log = $t->app->log->level('info');
$log->unsubscribe('message');
$log->on(message => sub { shift; push @log, [@_] });

subtest form => sub {
  $t->get_ok('/')
    ->status_is(200)
    ->text_like('body p' => qr/invitation/)
    ->element_exists('body form[action="/"][method="POST"]', 'got the form')
    ->element_exists_not('form:nth-of-type(2)', 'only one form')

    # because there's only one form I can be more lose about remaining selectors
    ->element_exists('form input[name="email"][type="email"]')
    ->element_exists('form input[name="first_name"]')
    ->element_exists('form input[name="last_name"]');
};

subtest success => sub {
  local $slack_form;
  local $mock_res = { ok => \1 };
  local @log;

  my $form = {
    email => 'user@company.com',
    first_name => 'Joë', # Check for UTF-8 cleanliness.
    last_name => '<User>', # Check HTML escaping.
  };

  $t->post_ok('/' => form => $form)
    ->status_is(200)
    ->text_like('body p' => qr/\Q$form->{email}/);

  is_deeply $slack_form, {
    token => 'API-TOKEN',
    channels => 'FOO,BAR,BAZ',
    email => 'user@company.com',
    first_name => 'Joë',
    last_name => '<User>',
    resend => 'true',
  };

  is_deeply \@log, [['info' => 'Invite sent for user@company.com']], 'got expected log output',
};

subtest 'api error' => sub {
  local $slack_form;
  local $mock_res = { ok => \0, error => 'API ERROR' };
  local @log;

  my $form = {
    email => 'user@company.com',
    first_name => 'Joë', # Check for UTF-8 cleanliness.
    last_name => '<User>', # Check HTML escaping.
  };

  $t->post_ok('/' => form => $form)
    ->status_is(500)
    ->text_like('body p' => qr/API ERROR/);

  is_deeply $slack_form, {
    token => 'API-TOKEN',
    channels => 'FOO,BAR,BAZ',
    email => 'user@company.com',
    first_name => 'Joë',
    last_name => '<User>',
    resend => 'true',
  };

  is $log[0][0], 'error', 'got expected log level';
  isa_ok $log[0][1], 'Mojo::Exception', 'got expected log object';
  like "$log[0][1]", qr/API ERROR/, 'got expected error message';
};

subtest 'not json' => sub {
  local $slack_form;
  local $mock_res = 'text is bad';
  local @log;

  my $form = {
    email => 'user@company.com',
    first_name => 'Joë', # Check for UTF-8 cleanliness.
    last_name => '<User>', # Check HTML escaping.
  };

  $t->post_ok('/' => form => $form)
    ->status_is(500)
    ->text_like('body p' => qr/JSON object/);

  is_deeply $slack_form, {
    token => 'API-TOKEN',
    channels => 'FOO,BAR,BAZ',
    email => 'user@company.com',
    first_name => 'Joë',
    last_name => '<User>',
    resend => 'true',
  };

  is $log[0][0], 'error', 'got expected log level';
  isa_ok $log[0][1], 'Mojo::Exception', 'got expected log object';
  like "$log[0][1]", qr/JSON object/, 'got expected error message';
};

done_testing;

1;

