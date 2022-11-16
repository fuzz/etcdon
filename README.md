# etcdon

etcdon is a friendly tool for managing Mastodon servers intended to be
accessible to folks who may not have much administration or programming
experience. It aims to provide sensible defaults and to be written in a simple
and clear style that can be easily understood and modified by non-programmers
to accomplish their goals.

etcdon is written against the [Digital Ocean 1-click Mastodon
install](https://marketplace.digitalocean.com/apps/mastodon), currently version
3.5.3, and may need modification for other installations.

Please note at this time etcdon is very much a work in progress.

etcdon is MIT licensed so you can fork it and do as you please.

## QuickStart

Note that the default configuration keeps up to 27 compressed backups of your
database--on a 50MB database that works out to ~200MB of backups. This is
fine on a smaller server or one with lots of disk space, but I am working to
adjust this to something more sensible as etcdon intends to be lean and nice,
despite those words not rhyming.

This script will ask for the hostname or IP address of your Mastodon server. If
your server is referred to by its domain name that is also its hostname. You
will be asked for your password to complete the install.

```
/bin/sh <(curl https://raw.githubusercontent.com/fuzz/etcdon/main/setup.sh)
```

If you wish to stop etcdon from running, type `crontab -r` into a terminal
window. You can re-run the setup script to start it again. You will also need
to run `sudo crontab -u postgres -r` on your server.

## Backups

Read this to understand what etcdon is doing. This will help you understand
what is happening if something goes wrong, how to modify it for you needs, etc.

etcdon backups have three primary components:
1. Cron jobs that run as the postgres user hourly generating compressed
   database backups and daily cleaning up all but the three most recent
1. `don` scripts that, among other things, gather files from the server to be
   backed up on your local machine or maybe a backup server or a trusted
   friend's server--additional documentation is below
1. Cron jobs that run on your local machine (or wherever your backups go) and
   call `don` to collect and prune backups

Additionally etcdon assumes that your local machine (or wherever your backups
go) is itself backed up. If this is not the case and you really don't want to
set backups up for some reason (backups are your friend!) you should take
additional backup steps as etcdon alone will not save you from scenarios like
data corruption on the server--etcdon will happily sync over the corrupt data,
leaving you bad data on both sides. Our database backups are largely immune to
this as we keep several copies of those, and keeping configs in a git repo as
recommended will protect those. Losing the Redis backup isn't catastrophic so
we don't worry about it. That leaves uploads, which are left as an exercise to
the sysop as they may be quite large--there's no one-size-fits-all solution
besides letting your local backup system take care of it (assuming you have the
room). Of course you can use S3 or similar for backups, and I may get around to
adding support for it, but etcdon is concerned most with you owning your own
data.

The official Mastodon backup documentation is
[here](https://docs.joinmastodon.org/admin/backups/).

The docs state "If you are using an external object storage provider such as
Amazon S3, Google Cloud or Wasabi, then you don’t need to worry about backing
(user-uploaded content) up." which is fine advice if your user-uploaded content
is reposted cat photos and the like. But, while services like S3 are quite
robust, if there's data you really care about losing you should back it up onto
hardware in your physical possession. etcdon does not support backing up files
to or from cloud object storage providers like S3 at this time.

Gathered files are copied into `local/`, which is gitignored by etcdon--if you
don't understand what this means, that's OK! You may want to manage
`local/configs` in its own git repository if you decide to tune/scale your
server, but you don't need to worry about any of that to get started.

### don commands for backup

don commands can be run with either the full name or the abbreviation, eg
`don install-crontab-postgres` and `don icp` are equivalent.

#### all | a

Copy backup, config and user files into the `local/` directory. See below for
details. Note this does not back up the secrets file as that only needs to
happen once--run `don gather-secrets` to back up the secrets file.

#### all-from-cron | afc

Same as `all` but outputs to `tmp/don-all.log` rather than your screen.

#### clean-backups-from-cron | cbfc

Remove all but the five most recent Postgres backups stored on the local
machine. Outputs to a log fie, `tmp/clean-backups.log`, rather than your
screen.

#### gather-configs | gc

Copy the files listed in `etc/gathered-configs` from the server into the
`local/` directory. `local/configs` is a good candidate for git management.

#### gather-databases | gd

Copy backup files from the server into the `local/` directory. This includes
the most recent Postgres backup as well as the current Redis dump. A new file
will be created for each Postgres backup; the Redis dump, however, will be
overwritten by design.

#### gather-secrets | gs

Copy `.env.production` from the server into the `local/` directory. This only
needs to be run once, though running it again won't hurt anything. You should
avoid exposing this file, checking it into a public git repository, etc.

#### gather-uploads | gu

Copy user-uploaded files from the server into the `local/` directory. The
official instructions say to backup the entire `public/server` directory, but
`gather-uploads` skips `public/server/cache` as it is rather large and can
presumably be regenerated from the network in the unlikely event it is lost.
See comments in `bin/gather-uploads` for rsync(1) considerations.

#### install-crontab-postgres | icp

Install a crontab for the postgres user. The included crontab creates a
compressed backup of the entire database every hour and cleans out all but the
most recent 3 backups every day. This only needs to be run once unless you
want to change postgres's crontab.

### Windows?

etcdon does not support Windows directly as I do not use Windows, but it should
work on [Cygwin](https://www.cygwin.com/) if you install the
[cron](https://cygwin.com/packages/summary/cron.html),
[git](https://cygwin.com/packages/summary/git.html),
[openssh](https://cygwin.com/packages/summary/openssh.html) and
[rsync](https://www.cygwin.com/packages/summary/rsync.html) packages and use
`ln -vfs ~/.config/etcdon/bin/don /usr/bin/` in place of the `sudo ln -vfs
~/.config/etcdon/bin/don /usr/local/bin/` command in the QuickStart below. You
should use the Cygwin terminal window rather than the Windows terminal window
to set up etcdon.

## Tuning

This section is more advanced than the Backups section and only needed if you
need to tune the performance of your Mastodon server. If your server is
performing well you should probably leave it alone.

This section is incomplete as I am currently taking my own advice and not
tuning the performance of my server--it's running just fine for now. I'll flesh
this out when I tune my instance, but in the meantime the links and
documentation below should be useful.

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
