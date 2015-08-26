# Karafka

[![Build Status](https://travis-ci.org/karafka/karafka.png)](https://travis-ci.org/karafka/karafka)
[![Code Climate](https://codeclimate.com/github/karafka/karafka/badges/gpa.svg)](https://codeclimate.com/github/karafka/karafka)

Microframework used to simplify Apache Kafka based Ruby applications development.

## How does it work

Karafka is a microframework to work easier with Apache Kafka incoming messages.

## Installation

Karafka does not have yet a standard installation shell commands. In order to install it, please follow given steps:

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

| Option                  | Value type    | Description                                                                          |
|-------------------------|---------------|--------------------------------------------------------------------------------------|
| zookeeper_hosts         | Array<String> | Zookeeper server hosts                                                               |
| kafka_hosts             | Array<String> | Kafka server hosts                                                                   |
| worker_timeout          | Integer       | How long a task can run in Sidekiq before it will be terminated                      |
| concurency              | Integer       | How many threads (Celluloid actors) should we have that listen for incoming messages |

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


## Sending messages from Karafka

To add ability to send messages you need add **waterdrop** gem to your Gemfile.

Please follow [WaterDrop README](https://github.com/karafka/waterdrop/blob/master/README.md) for more details on how to install and use it.

## Usage

### Receiving messages

First create application as it was written in **Installation** section above.
It will generate app folder with controllers and models folder, app.rb file, config folder with sidekiq.yml.example file,
log folder where karafka logs will be written(based on environment), rakefile.rb file to have ability to run karafka rake tasks.

Now, to have ability to receive messages you should define controllers in app/controllers folder. Controllers should inherit from Karafka::BaseController.
You have to define following elements in every controller:

 - *perform* - method that will execute the code in a Sidekiq worker
 - *group* - symbol/string with a group name. Groups are used to cluster applications
 - *topic* - symbol/string with a topic to which this controller should listen

Group and topic should be unique. You can't define different controllers with the same group or topic names, it will raise error.

You can add any number of *before_enqueue* callbacks. It can be method or block.
before_enqueue acts in a similar way to Rails before_action so it should perform "lightweight" operations. You have access to params inside. Based on it you can define which data you want to receive and which not.
If any of callbacks returns false - *perform* method will be not enqueued to Sidekiq Worker (the execution chain will stop).

SidekiqWorker is inherited from [SidekiqGlass](https://github.com/karafka/sidekiq-glass), so it uses reentrancy. If you want to use it, you should add *after_failure* method in the controller as well.
To run Sidekiq worker you should have sidekiq.yml file in *config* folder. The example of sidekiq.yml file will be generated to config/sidekiq.yml.example once you run **rake karafka:install**.

Once you run consumer - messages from Kafka server will be send to needed controller (based on topic name).

Presented example controller will accept incoming messages from a Kafka topic named :karafka_topic

```ruby
  class TestController < Karafka::BaseController
    self.group = :karafka_group
    self.topic = :karafka_topic

    # before_enqueue has access to received params.
    # You can modify them before enqueue it to sidekiq queue.
    before_enqueue {
      params.merge!(received_time: Time.now.to_s)
    }

    before_enqueue :validate_params

    # Method execution will be enqueued in Sidekiq.
    def perform
      Service.new.add_to_queue(params[:message])
    end

    # Define this method if you want to use Sidekiq reentrancy.
    # Logic to do if Sidekiq worker fails.
    # E.g. because it takes more time than you define in config.worker_timeout setting.
    def after_failure
      Service.new.remove_from_queue(params[:message])
    end

    private

   # We will not enqueue to sidekiq those messages,
   # which were sent from sum method and return too high message for our purpose.
   def validate_params
     params['message'].to_i > 50 && params['method'] != 'sum'
   end
end
```

## Concurency

Karafka uses Celluloid actors to handle listening to incoming connections. Since each topic and group requires a separate connection (which means that we have a connection per controller) we do this concurrently. To prevent Karafka from spawning hundred of threads (in huge application) you can specify concurency level configuration option. If this number matches (or exceeds) your controllers amount, then you will listen to all the topics simultaneously. If it is less then number of controllers, it will use a single thread to check for few topics (one after another). If this value is set to 1, it will just spawn a single thread to check all the sockets one after another.

## Note on Patches/Pull Requests

Fork the project.
Make your feature addition or bug fix.
Add tests for it. This is important so I don't break it in a future version unintentionally.
Commit, do not mess with Rakefile, version, or history. (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
Send me a pull request. Bonus points for topic branches.
