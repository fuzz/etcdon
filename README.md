# etcdon

etcdon is a tool for managing Mastodon. The scripts are POSIX shell but etcdon
itself is not POSIX compliant as it relies on tools like rsync(1). etcdon is
written against the [Digital Ocean 1-click Mastodon
install](https://marketplace.digitalocean.com/apps/mastodon), currently version
3.5.3, and may need modification for other installations.

Please note etcdon at this time etcdon is very much a work in progress.

etcdon is MIT licensed so you can fork it and do as you please.

## Configuration

You do not need to set `DON_PATH` if you install etcdon in `~/.config/etcdon`,
otherwise set it to the directory in which you do have etcdon installed.

Set `DON_HOST` to the hostname or IP address of your Mastodon server.

You may wish to copy/link `bin/don` into your `PATH` for convenience. The rest
of this documentation will assume that you have done this.

## Backups

The official Mastodon backup documentation is
[here](https://docs.joinmastodon.org/admin/backups/).

The docs state "If you are using an external object storage provider such as
Amazon S3, Google Cloud or Wasabi, then you don’t need to worry about backing
(user-uploaded content) up." which is fine advice if your user-uploaded content
is reposted cat photos and the like. But, while I do not mean to cast
aspersions, I have spoken at length with the team at AWS responsible for moving
data around and I did not come away with the impression that they are
infallible. If there's data you care about losing you definitely should back
it up yourself.

Gathered files are copied into `local/`, which is gitignored by etcdon--
you may want to manage `local/config` in its own git repo or similar.

### don commands for backup

don commands can be run with either the full name or the abbreviation, eg
`don install-crontab-postgres` and `don icp` are equivalent.

#### all | a

Copy backup, config and user files into the `local/` directory. See below for
details. Note this does not back up the secrets file as that only needs to
happen once--run `don gather-secrets` to back up the secrets file.

`5 12 * * * don all` added to your local crontab will back up your server to
your local machine every day five minutes after noon. If you don't have an
existing local crontab you can run `crontab etc/crontab-local` to install one
that contains the above line--this action will overwrite an existing crontab.

#### gather-backups | gb

Copy backup files from the server into the `local/` directory. This includes
the most recent Postgres backup as well as the current Redis dump. You may want
to call this from cron periodically on your local machine. A new file will be
created for each Postgres backup; the Redis dump, however, will be overwritten
by design.

#### gather-config-files | gcf

Copy the files listed in `etc/gathered-config-files` from the server into the
`local/` directory. You may wish to call this from cron periodically on your
local machine. These backup files are good candidate for git management.

#### gather-secrets | gs

Copy `.env.production` from the server into the `local/` directory. This only
needs to be run once, though running it again won't hurt anything. You should
avoid exposing this file, checking it into a public git repository, etc.

#### gather-user-files | guf

Copy user-uploaded files from the server into the local/ directory. The
official instructions say to backup the entire `public/server` directory, but
`gather-user-files` skips `public/server/cache` as it is rather large and can
presumably be regenerated from the network in the unlikely event it is lost.

#### install-crontab-postgres | icp

Install a crontab for the postgres user. The included crontab creates a
compressed backup of the entire database every hour and cleans out all but the
most recent 25 backups every day. This only needs to be run once unless you
want to change postgres's crontab.

## Tuning

The official tuning (they call it "scaling" but you don't require scale to
benefit from tuning) guide is
[here](https://docs.joinmastodon.org/admin/scaling/).

[This
article](https://nora.codes/post/scaling-mastodon-in-the-face-of-an-exodus/) is
required reading but mostly focused on Docker.

### Environment variables

These are the relevant tuning knobs I know about so far; there are likely
more.

```
DB_POOL
MAX_THREADS
PUMA_MAX_THREADS  # you probably don't need this
RAILS_MAX_THREADS # you probably don't need this
Sidekiq.options[:concurrency]
Sidekiq.options[:queues]
STREAMING_CLUSTER_NUM
WEB_CONCURRENCY
```

The below are from the [Digital Ocean 1-Click Mastodon
install](https://marketplace.digitalocean.com/apps/mastodon), version
3.5.3--other installations may differ.

```
app/lib/redis_configuration.rb:
def pool_size
  if Sidekiq.server?
    Sidekiq.options[:concurrency]
  else
    ENV['MAX_THREADS'] || 5
  end
end

config/database.yml: pool: <%= ENV["DB_POOL"] || ENV['MAX_THREADS'] || 5 %>

config/puma.rb: threads_count = ENV.fetch('MAX_THREADS') { 5 }.to_i

config/puma.rb: workers: ENV.fetch('WEB_CONCURRENCY') { 2 }

# Sidekiq.options[:concurrency] and Sidekiq.options[:queues] are set here
config/sidekiq.yml:
:concurrency: 5
:queues:
  - [default, 6]
  - [push, 4]
  - [mailers, 2]
  - [pull]
  - [scheduler]

# systemd(1) uses this to set DB_POOL
dist/mastodon-sidekiq.service: Environment="DB_POOL=25"

# systemd(1) uses this to set STREAMING_CLUSTER_NUM
dist/mastodon-streaming.service: Environment="STREAMING_CLUSTER_NUM=1"

lib/mastodon/redis_config.rb:
pool_size: Sidekiq.server? ? Sidekiq.options[:concurrency] : Integer(ENV['MAX_THREADS'] || 5)

lib/redis_configuration.rb: ENV['MAX_THREADS'] || 5

streaming/index.js:
const numWorkers = +process.env.STREAMING_CLUSTER_NUM || (env === 'development' ? 1 : Math.max(os.cpus().length - 1, 1));

vendor/bundle/ruby/3.0.0/gems/puma-5.6.4/lib/puma/configuration.rb:
:max_threads => Integer(ENV['PUMA_MAX_THREADS'] || ENV['MAX_THREADS'] || default_max_threads),

vendor/bundle/ruby/3.0.0/gems/sidekiq-6.4.2/lib/sidekiq/redis_connection.rb:
size = if symbolized_options[:size]
          symbolized_options[:size]
        elsif Sidekiq.server?
          # Give ourselves plenty of connections.  pool is lazy
          # so we won't create them until we need them.
          Sidekiq.options[:concurrency] + 5
        elsif ENV["RAILS_MAX_THREADS"]
          Integer(ENV["RAILS_MAX_THREADS"])
        else
          5
        end
```
