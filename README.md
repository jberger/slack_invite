# Slack Invite

A Mojolicious script to send someone an invitation to a Slack channel.
It is a response to the application described in <http://blog.theperlshop.com/2018/09/12/sending-a-slack-invite-with-a-perl-cgi-script/>.
Mojolicious apps can run as-is under CGI environments.

This uses the undocumented [users.admin.invite API call](https://github.com/ErikKalkoken/slackApiDoc/blob/master/users.admin.invite.md).

Configuration can be placed in `app.conf` to override defaults

```perl
{
    # A legacy token: https://api.slack.com/custom-integrations/legacy-tokens
    slack_api_token => 'xxxx-xxxxxxxxx-xxxx',

    # Which channels you'd like to send an invitation to, comma-separated.
    slack_channels => '',

    # URL to call to invite users
    slack_api_url => 'https://slack.com/api/users.admin.invite',
}
```
