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

Advanced users may wish to read further for more general instructions; if that
doesn't sound like you, start here! Open a terminal window and type in the
following, replacing `hostname_or_ip_address_of_your_server` with the
hostname or IP address of your server. If you registered a domain and your
server is just referred to by its domain name, that is also its hostname.

```
mkdir -p ~/.config
git clone https://github.com/fuzz/etcdon.git ~/.config/etcdon
sudo ln -vfs ~/.config/etcdon/bin/don /usr/local/bin/
export DON_HOST=hostname_or_ip_address_of_your_server
don gather-secrets
```

### QuickStart DON_HOST

You also need to add the `export DON_HOST=hostname` line to (one of) your
shell's configuration files so it loads automatically in the future. On Ubuntu
this is a file named `.profile`, that is in your home directory. You can add
the line to it by typing the following, replacing `hostname` with the hostname
or IP address of your server.

```
echo "export DON_HOST=hostname" >> ~/.profile
```

On macOS instead use the following, replacing `hostname` with the hostname or
IP address of your server.

```
echo "export DON_HOST=hostname" >> /.zshenv
```

Be sure to use two ">>", which means "add to the end of the existing file",
rather than using just one ">", which means "overwrite the existing file".

If you are on a system other than macOS or Ubuntu you can use a search engine
to figure out the appropriate file for your system.

### QuickStart cron

Consider the following command carefully before deciding to run it. It will
install a `crontab` on your local machine that does two things:
1. Gathers backups from your server to your local machine every day at 5
   minutes after noon
1. Prunes all but the most recent 10 database backups from your local machine
   every Wedneday at 25 minutes after noon

If you do not want these things to happen, or want them to happen in a
different way or at different times, or you already have a crontab, do not run
this command. You'll need to write your own cron job(s) instead, which is
outside the scope of this documentation--you can learn more by typing in `man 5
crontab`.

```
crontab ~/.config/etc/crontab-local
```

If the above command completes successfully it will return no output in the
traditional "no news is good news" Unix style.

To uninstall the crontab and stop the behavior described above type in
`crontab -r`. You can reinstall it using the command above.

### QuickStart conclusion

If all of the commands above completed successfully, congratulations! You now
have backups, though you should still look through the Backups section below
for additional considerations and to learn more about what's going on in case
something goes wrong or you'd like to customize etcdon. You can skip past the
Configuration section that comes next; you already did that part.

## Configuration

Skip this section if you successfully completed the QuickStart above.

You do not need to set `DON_PATH` if you install etcdon in `~/.config/etcdon`,
otherwise set it to the directory in which you do have etcdon installed.

Set `DON_HOST` to the hostname or IP address of your Mastodon server.

You may wish to copy/link `bin/don` into your `PATH` for convenience. The rest
of this documentation will assume that you have done this.

## Backups

etcdon backups have three primary components:
1. Cron jobs that run as the postgres user hourly generating compressed
   database backups and daily cleaning up all but the 25 most recent
1. Scripts called by the `don` wrapper that gather files from the server to be
   backed up on your local machine or maybe a backup server or a trusted
   friend's server
1. Cron jobs that run on your local machine (or wherever your backups go) to
   collect and prune backups

Additionally etcdon assumes that your local machine (or wherever your backups
go) is itself backed up. If this is not the case and you really don't want to
set backups up for some reason (backups are your friend!) you should take
additional backup steps as etcdon alone will not save you from scenarios like
data corruption on the server--etcdon will happily sync over the corrupt data,
leaving you bad data on both sides. Our Postgres backups are
largely immune to this as we keep several copies of those, and keeping configs
in a git repo as recommended will protect those. Losing the Redis backup isn't
catastrophic so we don't worry about it. That leaves uploads, which are left as
an exercise to the sysop as they may be quite large--there's no
one-size-fits-all solution besides letting your local backup system take care
of it (assuming you have the room). Of course you can use S3 or similar for
backups, and I'll probably get around to adding support for it, but etcdon is
local first as much as possible.

The official Mastodon backup documentation is
[here](https://docs.joinmastodon.org/admin/backups/).

The docs state "If you are using an external object storage provider such as
Amazon S3, Google Cloud or Wasabi, then you don’t need to worry about backing
(user-uploaded content) up." which is fine advice if your user-uploaded content
is reposted cat photos and the like. But, while I do not mean to cast
aspersions, I have spoken at length with the team at AWS responsible for moving
data around and I did not come away with the impression that they are
infallible. If there's data you care about losing you definitely should back
it up yourself, however etcdon does not support backing up files stored on S3
at this time.

Gathered files are copied into `local/`, which is gitignored by
etcdon--you may want to manage `local/config` in its own git repo or similar.

### don commands for backup

don commands can be run with either the full name or the abbreviation, eg
`don install-crontab-postgres` and `don icp` are equivalent.

#### all | a

Copy backup, config and user files into the `local/` directory. See below for
details. Note this does not back up the secrets file as that only needs to
happen once--run `don gather-secrets` to back up the secrets file.

`5 12 * * * don all > /tmp/don-all.log` added to your local crontab will back
up your server to your local machine every day five minutes after noon.
`25 12 * * wed don clean-backups > /tmp/don-clean-backups.log`
will help keep your database backups under control on Wednesdays at 25 minutes
after noon. If you do not have an existing local crontab you can run `crontab
etc/crontab-local` to install one that contains the above entries--be aware
this action will overwrite an existing crontab.

#### clean-backups | cb

Remove all but the 10 most recent Postgres backups stored on the local machine.

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
