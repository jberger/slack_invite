use Mojolicious::Lite;

plugin Config => {
  default => {
    # A legacy token: https://api.slack.com/custom-integrations/legacy-tokens
    slack_api_token => 'xxxx-xxxxxxxxx-xxxx',

    # Which channels you'd like to send an invitation to, comma-separated.
    slack_channels => '',

    # URL to call to invite users
    slack_api_url => 'https://slack.com/api/users.admin.invite',
  }
};

helper send_slack_invite => sub {
  my ($c, $params) = @_;

  my $config = $c->app->config;

  my $form = {
    token => $config->{slack_api_token},
    channels => $config->{slack_channels},

    email => $params->{email},
    first_name => $params->{first_name},
    last_name => $params->{last_name},

    resend => 'true',
  };
  my $url = $config->{slack_api_url};

  my $data = $c->app->ua->post($url => form => $form)->result->json;

  die "API call did not return a JSON object"
      unless ref $data eq 'HASH';

  die $data->{error} unless $data->{ok};

  return 1;
};

get '/' => 'invite';

post '/' => sub {
  my $c = shift;
  my $params = $c->req->params->to_hash;
  $c->send_slack_invite($params);
  $c->app->log->info("Invite sent for $params->{email}");
  $c->render('success', email => $params->{email});
};

app->start;

__DATA__

@@ invite.html.ep
<html>
<head>
    <title>Get invited!</title>
</head>
<body>
    <p>We'd like to send you an invitation. Please fill out this form.</p>

      <form method="POST" action="/">
        <p>
          <span>Email: </span>
          <input type="email" name="email">
        </p>
        <p>
          <span>First Name: </span>
          <input name="first_name">
        </p>
        <p>
          <span>Last Name: </span>
          <input name="last_name">
        </p>
      </form>

</body>
</html>

@@ success.html.ep
<html>
<head>
    <title>You've been invited!</title>
</head>
<body>
    <p>An invitation has been sent to <%= $email %>.</p>

    <p>It should be in your inbox any time now!</p>

</body>
</html>


@@ exception.html.ep
<html>
<head>
    <title>Error</title>
</head>
<body>
    <p>We had a problem sending out your invitation because of the
    following error: <%= $exception->message %>.</p>
</body>
</html>

