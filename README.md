# Karafka

[![Build Status](https://travis-ci.org/karafka/karafka.png)](https://travis-ci.org/karafka/karafka)
[![Code Climate](https://codeclimate.com/github/karafka/karafka/badges/gpa.svg)](https://codeclimate.com/github/karafka/karafka)

Microframework used to simplify Apache Kafka based Ruby applications development.

## Table of Contents

  - [Table of Contents](#user-content-table-of-contents)
  - [How does it work](#user-content-how-does-it-work)
  - [Installation](#user-content-installation)
  - [Setup](#user-content-setup)
  - [Rake tasks](#user-content-rake-tasks)
  - [Usage](#user-content-usage)
    - [Sending messages from Karafka](#user-content-sending-messages-from-karafka)
    - [Receiving messages](#user-content-receiving-messages)
      - [Methods and attributes for every controller](#user-content-methods-and-attributes-for-every-controller)
      - [Optional attributes](#user-content-optional-attributes)
        - [Karafka controller topic](#user-content-karafka-controller-topic)
        - [Karafka controller group](#user-content-karafka-controller-group)
        - [Karafka controller custom worker](#user-content-karafka-controller-custom-worker)
        - [Karafka controller custom parser](#user-content-karafka-controller-custom-parser)
        - [Karafka controller custom interchanger](#user-content-karafka-controller-custom-interchanger)
      - [Controllers callbacks](#user-content-controllers-callbacks)
  - [Monitoring and logging](#user-content-monitoring-and-logging)
    - [Example monitor with Errbit support](#user-content-example-monitor-with-errbitairbrake-support)
    - [Example monitor with NewRelic support](#user-content-example-monitor-with-newrelic-support)
  - [Concurrency](#user-content-concurrency)
  - [Sidekiq Web UI](#user-content-sidekiq-web-ui)
  - [Articles and other references](#user-content-articles-and-other-references)
    - [Libraries and components](#user-content-libraries-and-components)
    - [Articles and references](#user-content-articles-and-references)
  - [Note on Patches/Pull Requests](#user-content-note-on-patchespull-requests)

## How does it work

Karafka is a microframework to work easier with Apache Kafka incoming messages.

## Installation

Karafka does not have yet a standard installation shell commands. In order to install it, please follow given steps:

Create a directory for your project:

```bash
mkdir app_dir
cd app_dir
```

Create a **Gemfile** with Karafka:

```ruby
source 'https://rubygems.org'

gem 'karafka', github: 'karafka/karafka'
```

Create a **rakefile.rb** with following code:

```ruby
ENV['KARAFKA_ENV'] ||= 'development'

Bundler.require(:default, ENV['KARAFKA_ENV'])
```

Bundle afterwards

```bash
bundle install
```

Execute the *karafka:install* rake task:

```bash
bundle exec rake karafka:install
```

## Setup

Karafka has following configuration options:

| Option                  | Value type    | Description                                                                          |
|-------------------------|---------------|--------------------------------------------------------------------------------------|
| zookeeper_hosts         | Array<String> | Zookeeper server hosts                                                               |
| kafka_hosts             | Array<String> | Kafka server hosts                                                                   |
| redis                   | Hash          | Hash with Redis configuration options (url and namespace)                            |
| worker_timeout          | Integer       | How long a task can run in Sidekiq before it will be terminated                      |
| concurrency             | Integer       | How many threads (Celluloid actors) should we have that listen for incoming messages |
| name                    | String        | Application name                                                                     |

To apply this configuration, you need to use a *setup* method from the Karafka::App class (app.rb):

```ruby
class App < Karafka::App
  setup do |config|
    config.kafka_hosts = %w( 127.0.0.1:9092 127.0.0.1:9093 )
    config.zookeeper_hosts =  %w( 127.0.0.1:2181 )
    config.redis = {
      url: 'redis://redis.example.com:7372/1',
      namespace: 'my_app_redis_namespace'
    }
    config.worker_timeout =  3600 # 1 hour
    config.concurrency = 10 # 10 threads max
    config.name = 'my_application'
  end
end
```

Note: You can use any library like [Settingslogic](https://github.com/binarylogic/settingslogic) to handle your application configuration.

If you want to do some configurations after all of this is done, please add to config directory a proper file (needs to inherit from Karafka::Config::Base and implement setup method) after that everything will happen automatically.

Example configuration class:

```ruby
class ExampleConfigurator < Base
  def setup
    ExampleClass.logger = Karafka.logger
    ExampleClass.redis = config.redis
  end
end
```


## Rake tasks

Karafka provides following rake tasks:

| Task                 | Description                                      |
|----------------------|--------------------------------------------------|
| rake karafka:install | Creates whole minimal app structure              |
| rake karafka:run     | Runs a single Karafka processing instance        |
| rake karafka:sidekiq | Runs a single Sidekiq worker for Karafka         |
| rake kafka:topics    | Lists all the topics available on a Kafka server |


## Usage

### Sending messages from Karafka

To add ability to send messages you need to add **waterdrop** gem to your Gemfile.

Please follow [WaterDrop README](https://github.com/karafka/waterdrop/blob/master/README.md) for more details on how to install and use it.

### Receiving messages

First create application as it was written in the installation section above.
It will generate app folder with controllers and models folder, app.rb file, config folder with sidekiq.yml.example file,
log folder where karafka logs will be written(based on environment), rakefile.rb file to have ability to run karafka rake tasks.

#### Methods and attributes for every controller

Now, to have ability to receive messages you should define controllers in app/controllers folder. Controllers should inherit from Karafka::BaseController. If you don't want to use custom workers (and except some particular cases you shouldn't), yo need to define a #perform method that will be execute your business logic code in a Sidekiq worker

####  Optional attributes

Karafka controller has four optional attributes: **topic**, **group**, **parser**, **worker** and **interchanger**.

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

Custom workers need to provide a **#perform_async** method. It needs to accept two arguments:

 - *controller class* - first argument is a current controller class (controller that schedules the job)
 - *params* - all the params that came from Kafka + additional metadata. This data format might be changed if you use custom interchangers. Otherwise it will be an instance of Karafka::Params::Params

Keep in mind, that params might be in two states: parsed or unparsed when passed to #perform_async. This means, that if you use custom interchangers and/or custom workers, you might want to look into Karafka's sources to see exactly how it works.

##### Karafka controller custom parser

 - *parser* - Class name - name of a parser class that we want to use to parse incoming data

Karafka by default will parse messages with JSON parser. If you want to change this behaviour you need to set parser in controller. Parser needs to have a #parse method and raise error that is a ::Karafka::Errors::ParserError descendant when problem appears during parsing process.

```ruby
class TestController < Karafka::BaseController
  # This can be any type of parser that provides a parse method
  # and raise ParseError when error appear during parsing
  self.parser = XmlParser
end

class XmlParser
  class ParserError < ::Karafka::Errors::ParserError; end

  def self.parse(message)
    Hash.from_xml(message)
  rescue REXML::ParseException
    raise ParserError
  end
end
```

Note that parsing failure won't stop the application flow. Instead, Karafka will assign the raw message inside the :message key of params. That way you can handle raw message inside the Sidekiq worker (you can implement error detection, etc - any "heavy" parsing logic can and should be implemented there).

##### Karafka controller custom interchanger

 - *interchanger* - Class name - name of a interchanger class that we want to use to format data that we put/fetch into/from #perform_async.

Custom interchangers target issues with non-standard (binary, etc) data that we want to store when we do #perform_async. This data might be corrupted when fetched in a worker (see [this](https://github.com/karafka/karafka/issues/30) issue). With custom interchangers, you can encode/compress data before it is being passed to scheduling and decode/decompress it when it gets into the worker.

**Warning**: if you decide to use slow interchangers, they might significantly slow down Karafka.

```ruby
class TestController < Karafka::BaseController
  self.interchanger = Base64Interchanger
end

class Base64Interchanger
  class << self
    def load(params)
      Base64.encode64(Marshal.dump(params))
    end

    def parse(params)
      Marshal.load(Base64.decode64(params))
    end
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

### Monitoring and logging

Karafka provides a simple monitor (Karafka::Monitor) with a really small API. You can use it to develop your own monitoring system (using for example NewRelic). By default, the only thing that is hooked up to this monitoring is a Karafka logger (Karafka::Logger). It is based on a standard [Ruby logger](http://ruby-doc.org/stdlib-2.2.3/libdoc/logger/rdoc/Logger.html).

To change monitor or a logger, you can just simply replace them:

```ruby
Karafka.monitor = CustomMonitor.new
Karafka.logger = CustomLogger.new
```

Keep in mind, that if you replace monitor with a custom one, you will have to implement logging as well. It is because monitoring is used for both monitoring and logging and a default monitor handles logging as well.

#### Example monitor with Errbit/Airbrake support

Here's a simple example of monitor that is used to handle errors logging into Airbrake/Errbit.

```ruby
class AppMonitor < Karafka::Monitor
  def notice_error(caller_class, e)
    super
    Airbrake.notify_or_ignore(e)
  end
end
```

#### Example monitor with NewRelic support

Here's a simple example of monitor that is used to handle events and errors logging into NewRelic. It will send metrics with information about amount of processed messages per topic and how many of them were scheduled to be performed async.

```ruby
class AppMonitor < Karafka::Monitor
  def notice(caller_class, options = {})
    super
    action = :"notice_#{caller_label}"
    return unless respond_to?(action, true)
    send(action, caller_class, options)
  end

  def notice_error(caller_class, e)
    super
    NewRelic::Agent.notice_error(e)
  end

  private

  def notice_consume(_caller_class, options)
    record_count metric_key(options[:controller_class], __method__)
  end

  def notice_perform_async(caller_class, _options)
    record_count metric_key(caller_class, __method__)
  end

  def metric_key(caller_class, method_name)
    "Custom/#{caller_class.topic}/#{method_name}"
  end

  def record_count(key)
    NewRelic::Agent.record_metric(key, count: 1)
  end
end
```

## Concurrency

Karafka uses [Celluloid](https://celluloid.io/) actors to handle listening to incoming connections. Since each topic and group requires a separate connection (which means that we have a connection per controller) we do this concurrently. To prevent Karafka from spawning hundred of threads (in huge application) you can specify concurency level configuration option. If this number matches (or exceeds) your controllers amount, then you will listen to all the topics simultaneously. If it is less then number of controllers, it will use a single thread to check for few topics (one after another). If this value is set to 1, it will just spawn a single thread to check all the sockets one after another.

## Sidekiq Web UI

Karafka comes with a Sidekiq Web UI application that can display the current state of a Sidekiq installation. If you installed Karafka using install rake task, you will have a **config.ru** file that allows you to run standalone Puma instance with a Sidekiq Web UI:

```
bundle exec rackup
# Puma starting...
# * Min threads: 0, max threads: 16
# * Environment: development
# * Listening on tcp://localhost:9292
```

You can then navigate to displayer url to check your Sidekiq status. Sidekiq Web UI by default is password protected. To check (or change) your login and password, please review **config.ru** file in your application.

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
* [Benchmarking Karafka – how does it handle multiple TCP connections](http://dev.mensfeld.pl/2015/11/benchmarking-karafka-how-does-it-handle-multiple-tcp-connections/)
* [Karafka – Ruby framework for building Kafka message based applications (presentation)](http://mensfeld.github.io/karafka-framework-introduction/)
* [Karafka example application](https://github.com/karafka/karafka-example-app)
* [Karafka Travis CI](https://travis-ci.org/karafka/karafka)
* [Karafka Code Climate](https://codeclimate.com/github/karafka/karafka)

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
