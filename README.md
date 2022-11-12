# etcdon

These are YAML-free tools for managing Mastodon. The scripts themselves are
POSIX shell but they do rely on They are written against the
Digital Ocean one-click Mastodon install and may need to be modified for other
installations.

## Configuration

You do not need to set `DON_PATH` if you install etcdon in `~/.config/etcdon`,
otherwise set it to the directory in which you do have etcdon installed.

Set `DON_HOST` to the IP address of your Mastodon server.

## Tuning

The official documentation is
[here](https://docs.joinmastodon.org/admin/scaling/).

[This
article](https://nora.codes/post/scaling-mastodon-in-the-face-of-an-exodus/) is
very helpful but mostly focused on Docker.

### Environment variables

| file | relevant code |
|------|---------------|
| config/database.yml | `<%= ENV["DB_POOL"] \|\| ENV['MAX_THREADS'] \|\| 5 %>` |
| config/puma.rb | `threads_count = ENV.fetch('MAX_THREADS') { 5 }.to_i` |
| config/puma.rb | `workers: ENV.fetch('WEB_CONCURRENCY') { 2 }` |
| dist/mastodon-streaming.service | `Environment="STREAMING_CLUSTER_NUM=1"` |
| lib/mastodon/redis_config.rb | `pool_size: Sidekiq.server? ? Sidekiq.options[:concurrency] : Integer(ENV['MAX_THREADS'] \|\| 5)` |
| lib/redis_configuration.rb | `ENV['MAX_THREADS'] \|\| 5` |
| streaming/index.js | `const numWorkers = +process.env.STREAMING_CLUSTER_NUM \|\| (env === 'development' ? 1 : Math.max(os.cpus().length - 1, 1));` |

```
DB_POOL
MAX_THREADS
PUMA_MAX_THREADS
RAILS_MAX_THREADS
STREAMING_CLUSTER_NUM # set: mastodon-streaming.service read: streaming/index.js
WEB_CONCURRENCY
```
