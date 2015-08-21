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

## Usage

### Receiving messages

First create application as it was written in **Installation** section above.
It will generate app folder with controllers and models folder, app.rb file, config folder with sidekiq.yml.example file.
Also you should have log folder where karafka logs will be written, rakefile.rb file to have ability to run karafka rake tasks.

Example of rakefile.rb:

```ruby
  ENV['KARAFKA_ENV'] ||= 'development'

  require './app.rb'

  task(:environment) {}

  Karafka::Loader.new.load(Karafka::App.root)

  Dir.glob('lib/tasks/*.rake').each { |r| load r }
```

Now, to have ability to receive messages you should define controllers in app/controllers folder inherited from Karafka::BaseController. Controller should define *perform* method and has *group* and *topic* names. Names should be unique. You should not define different controllers with the same group or topic names.

You can add any number of *before_enqueue* callbacks. It can be method or block. Write here logic which will not take long time to implement. You have access to params. Based on it you can define which data you want to receive and which not.
Once at least one of callbacks returns false - *perform* method will be not enqueued to Sidekiq Worker.

SidekiqWorker is inherited from [SidekiqGlass](https://github.com/karafka/sidekiq-glass), so it uses reentrancy. If you want to use it, you should add *after_failure* method in controller as well.
To run Sidekiq worker you should have sidekiq.yml file in *config* folder. The example of sidekiq.yml file will be generated to config/sidekiq.yml.example once you run **rake karafka:install**.

One you run consumer - all messages from Kafka server will be received to needed controller. Routing to controller is based on topic name.

This controller will receive the message based on topic name(:karafka_topic).

```ruby
  class TestController < Karafka::BaseController
    self.group = :karafka_group
    self.topic = :karafka_topic

    before_enqueue {
      # Logic here. Has access to params.
    }

    before_enqueue :validate_params

    # Method execution will be enqueued in Sidekiq.
    # Example of perform method which writes **params** into log file.
    def perform
      file = File.open('params.log', 'a+')
      file.write "Topic #{self.class.topic} receive params #{params}\n"
      file.close
    end

    # You can not define this method once you don’t want to use Sidekiq reentrancy.
    def after_failure
      # Logic to do once Sidekiq worker will fail. E.g. because it takes more time than you define in config.worker_timeout setting.
    end

    private

   def validate_params
     # Logic here. Has access to params.
   end
end
```

## Note on Patches/Pull Requests

Fork the project.
Make your feature addition or bug fix.
Add tests for it. This is important so I don't break it in a future version unintentionally.
Commit, do not mess with Rakefile, version, or history. (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
Send me a pull request. Bonus points for topic branches.
