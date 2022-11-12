# etcdon

etcdon is a tool for managing Mastodon. The scripts are POSIX shell but etcdon
itself is not POSIX compliant as it relies on tools like rsync(1). etcdon is
written against the [Digital Ocean 1-click Mastodon
install](https://marketplace.digitalocean.com/apps/mastodon), currently version
3.5.3, and may need modification for other installations.

Please note etcdon at this time etcdon is a work in progress, meaning I will
close any Issues opened without addressing them and, while I might accept a PR,
I also might not. If and when I make a release of etcdon then Issues and PRs
will be welcomed. That said, feel free to reach out @fuzz@pine.cab.

etcdon is MIT licensed so you can fork it and do as you please.

## Configuration

You do not need to set `DON_PATH` if you install etcdon in `~/.config/etcdon`,
otherwise set it to the directory in which you do have etcdon installed.

Set `DON_HOST` to the IP address of your Mastodon server.

## Backups

The official backup documentation is
[here](https://docs.joinmastodon.org/admin/backups/).

The docs state "If you are using an external object storage provider such as
Amazon S3, Google Cloud or Wasabi, then you don’t need to worry about backing
(user loaded) up." which is fine advice if your user-uploaded content is
reposted cat photos and the like. But, and I do not mean to cast aspersions, I
have spoken at length with the team at AWS responsible for moving data around
and I did not come away with the impression that they are infallible. If
there's data you care about losing you definitely want to back it up yourself.

### local/

Stores gathered configuration and backup files. local/ is ignored by etcdon--
you may want to manage some or all of its contents with git or similar.

### bin/install-crontab-postgres

Install a crontab for the postgres user. The included crontab creates a
compressed backup of the entire database every hour and cleans out all but the
most recent 25 backups every day.

### bin/gather-backups

Copy backup files from the server into the local/ directory. You may want to
call this from cron periodically on your local machine.

### bin/gather-config-files

Copy the files listed in `etc/gathered-config-files` from the server into the
local/ directory. You may wish to call this from cron periodically on your
local machine.

## Tuning

The official tuning (they call it "scaling" but you don't require scale to
benefit from tuning) is
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
