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
| redis_url               | String        | Redis server url                                                                    |
| redis_namespace         | String        | Redis namespace                                                                      |
| worker_timeout          | Integer       | How long a task can run in Sidekiq before it will be terminated                      |
| concurrency             | Integer       | How many threads (Celluloid actors) should we have that listen for incoming messages |
| name                    | String        | Application name                                                                     |

To apply this configuration, you need to use a *setup* method from the Karafka::App class (app.rb):

```ruby
class App < Karafka::App
  setup do |config|
    config.kafka_hosts = %w( 127.0.0.1:9092 127.0.0.1:9093 )
    config.zookeeper_hosts =  %w( 127.0.0.1:2181 )
    config.redis_url = 'redis://redis.example.com:7372/1'
    config.redis_namespace = 'my_app_redis_namespace'
    config.worker_timeout =  3600 # 1 hour
    config.concurrency = 10 # 10 threads max
    config.name = 'my_application'
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


## Usage

### Sending messages from Karafka

To add ability to send messages you need to add **waterdrop** gem to your Gemfile.

Please follow [WaterDrop README](https://github.com/karafka/waterdrop/blob/master/README.md) for more details on how to install and use it.

### Receiving messages

First create application as it was written in the installation section above.
It will generate app folder with controllers and models folder, app.rb file, config folder with sidekiq.yml.example file,
log folder where karafka logs will be written(based on environment), rakefile.rb file to have ability to run karafka rake tasks.

#### Methods and attributes for every controller

Now, to have ability to receive messages you should define controllers in app/controllers folder. Controllers should inherit from Karafka::BaseController.

You have to define following elements in every controller:

 - method *perform* - method that will execute the code in a Sidekiq worker

####  Optional attributes

Karafka controller has four optional attributes: **topic**, **group**, **parser** and **worker**.

##### Karafka controller topic

 - *topic* - symbol/string with a topic to which this controller should listen

By default topic is taken from the controller name (similar to Rails routes). It will also include any namespace name in which the controller is defined. Here you have few examples on what type of topic you will get based on the controller name (with namespaces):

```ruby
VideosUploadedController => :videos_uploaded
Source::EventsController => :source_events
DataApp::Targets::UsersTargetsController => :data_app_targets_users_targets
```

You can of course overwrite it and set any topic you want:

```ruby
class TestController < Karafka::BaseController
  self.topic = :prefered_topic_name
end
```

##### Karafka controller group

 - *group* - symbol/string with a group name. Groups are used to cluster applications

Also you can optionally define **group** attribute if you want to build many applications that will share the same Kafka group. Otherwise it will just build it based on the **topic** and **name**. If you're not planning to build applications that will load-balance messages between many different applications (but between one applications many processes), you may want not to define it and allow the framework to define it for you. Otherwise set:

Group and topic should be unique. You can't define different controllers with the same group or topic names, it will raise error.

##### Karafka controller custom worker

 - *worker* - Class name - name of a worker class that we want to use to schedule perform code

Karafka by default will build a worker that will correspond to each of your controllers (so you will have a pair - controller and a worker). All of them will inherit from **Karafka::Workers::BaseWorker** and will share all its settings. **Karafka::Workers::BaseWorker**.

Karafka::Workers::BaseWorker inherits from [SidekiqGlass::Worker](https://github.com/karafka/sidekiq-glass), so it uses reentrancy. If you want to use it, you should add *after_failure* method in the controller as well.

To run Sidekiq you should have sidekiq.yml file in *config* folder. The example of sidekiq.yml file will be generated to config/sidekiq.yml.example once you run **rake karafka:install**.

However, if you want to use a raw Sidekiq worker (without any Karafka additional magic), or you want to use SidekiqPro (or any other queuing engine that has the same API as Sidekiq), you can assign your own custom worker:

```ruby
class TestController < Karafka::BaseController
  # This can be any type of worker that provides a perform_async method
  self.worker = MyDifferentWorker
end
```

##### Karafka controller custom parser

 - *parser* - Class name - name of a parser class that we want to use to parse incoming data

Karafka by default will parse messages with JSON parser. If you want to change this behaviour you need to set parser in controller. This parser should contain parse method and raise ParserError when appear problem with parsing.

```ruby
class TestController < Karafka::BaseController
  # This can be any type of parser that provides a parse method
  # and raise ParseError when error appear during parsing
  self.parser = XmlParser
end

class XmlParser
  class ParserError < StandardError; end

  def self.parse(message)
    Hash.from_xml(message)
  rescue REXML::ParseException
    raise ParserError
  end
end
```

#### Controllers callbacks

You can add any number of *before_enqueue* callbacks. It can be method or block.
before_enqueue acts in a similar way to Rails before_action so it should perform "lightweight" operations. You have access to params inside. Based on it you can define which data you want to receive and which not.

**Warning**: keep in mind, that all *before_enqueue* blocks/methods are executed after messages are received. This is not executed in Sidekiq, but right after receiving the incoming message. This means, that if you perform "heavy duty" operations there, Karafka might significantly slow down.

If any of callbacks returns false - *perform* method will be not enqueued to the worker (the execution chain will stop).

Once you run consumer - messages from Kafka server will be send to a proper controller (based on topic name).

Presented example controller will accept incoming messages from a Kafka topic named :karafka_topic

```ruby
  class TestController < Karafka::BaseController
    self.group = :karafka_group # group is optional
    self.topic = :karafka_topic # topic is optional

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
    # Logic to do if Sidekiq worker fails (because of exception, timeout, etc)
    def after_failure
      Service.new.remove_from_queue(params[:message])
    end

    private

   # We will not enqueue to sidekiq those messages, which were sent
   # from sum method and return too high message for our purpose.
   def validate_params
     params['message'].to_i > 50 && params['method'] != 'sum'
   end
end
```

## Concurrency

Karafka uses [Celluloid](https://celluloid.io/) actors to handle listening to incoming connections. Since each topic and group requires a separate connection (which means that we have a connection per controller) we do this concurrently. To prevent Karafka from spawning hundred of threads (in huge application) you can specify concurency level configuration option. If this number matches (or exceeds) your controllers amount, then you will listen to all the topics simultaneously. If it is less then number of controllers, it will use a single thread to check for few topics (one after another). If this value is set to 1, it will just spawn a single thread to check all the sockets one after another.

## Articles and other references

### Libraries and components

* [Karafka framework](https://github.com/karafka/karafka)
* [Waterdrop](https://github.com/karafka/waterdrop)
* [Sidekiq Glass](https://github.com/karafka/sidekiq-glass)
* [Envlogic](https://github.com/karafka/envlogic)
* [Apache Kafka](http://kafka.apache.org/)
* [Apache ZooKeeper](https://zookeeper.apache.org/)

### Articles and references

* [Karafka – Ruby micro-framework for building Apache Kafka message-based applications](http://dev.mensfeld.pl/2015/08/karafka-ruby-micro-framework-for-building-apache-kafka-message-based-applications/)
* [Karafka example application](https://github.com/karafka/karafka-example-app)

## Note on Patches/Pull Requests

Fork the project.
Make your feature addition or bug fix.
Add tests for it. This is important so I don't break it in a future version unintentionally.
Commit, do not mess with Rakefile, version, or history. (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull). Send me a pull request. Bonus points for topic branches.

Each pull request must pass our quality requirements. To check if everything is as it should be, we use [PolishGeeks Dev Tools](https://github.com/polishgeeks/polishgeeks-dev-tools) that combine multiple linters and code analyzers. Please run:

```bash
bundle exec rake
```

to check if everything is in order. After that you can submit a pull request.
