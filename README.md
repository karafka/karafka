# Karafka

[![Build Status](https://travis-ci.org/karafka/karafka.png)](https://travis-ci.org/karafka/karafka)
[![Code Climate](https://codeclimate.com/github/karafka/karafka/badges/gpa.svg)](https://codeclimate.com/github/karafka/karafka)

Microframework used to simplify Kafka based Ruby applications

## How does it work

Karafka is a microframework to work easier with Kafka incoming events.

## Installation

Karafka does not have yet a standard installation shell command. In order to install it, please follow given steps:

Create a directory for your project:

```bash
mkdir app_dir
cd app_dir
```

Create a Gemfile with Karafka:

```bash
echo "source 'https://rubygems.org'" > Gemfile
echo "gem 'karafka'" >> Gemfile
```

Bundle afterwards

```bash
bundle install
```

Execute the *karafka:install rake* task:

```bash
bundle exec rake karafka:install
```

## Setup

Karafka has following configuration options:

| Option                  | Value type    | Description                                                     |
|-------------------------|---------------|-----------------------------------------------------------------|
| zookeeper_hosts         | Array<String> | Zookeeper server hosts                                          |
| kafka_hosts             | Array<String> | Kafka server hosts                                              |
| worker_timeout          | Integer       | How long a task can run in Sidekiq before it will be terminated |

To apply this configuration, you need to use a *setup* method from the Karafka::App class (app.rb):

```ruby
class App < Karafka::App
  setup do |config|
    config.kafka_hosts = %w( 127.0.0.1:9092 127.0.0.1:9093 )
    config.zookeeper_hosts =  %w( 127.0.0.1:2181 )
    config.worker_timeout =  3600 # 1 hour
  end
end
```

Note: You can use any library like [Settingslogic](https://github.com/binarylogic/settingslogic) to handle your application configuration.

## Rake tasks

Karafka provides following rake tasks:

| Task                 | Description                               |
|----------------------|-------------------------------------------|
| rake karafka:install | Creates whole minimal app structure       |
| rake karafka:run     | Runs a single Karafka processing instance |
| rake karafka:sidekiq | Runs a single Sidekiq worker for Karafka  |

## Sending events from Karafka

To add ability to send events you need add **waterdrop** gem to your Gemfile.

Please follow [WaterDrop README](https://github.com/karafka/waterdrop/blob/master/README.md) for more details on how to install and use it.

## Note on Patches/Pull Requests

Fork the project.
Make your feature addition or bug fix.
Add tests for it. This is important so I don't break it in a future version unintentionally.
Commit, do not mess with Rakefile, version, or history. (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
Send me a pull request. Bonus points for topic branches.
