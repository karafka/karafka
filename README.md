# Karafka

[![Build Status](https://travis-ci.org/karafka/karafka.png)](https://travis-ci.org/karafka/karafka)
[![Code Climate](https://codeclimate.com/github/karafka/karafka/badges/gpa.svg)](https://codeclimate.com/github/karafka/karafka)
[![Join the chat at https://gitter.im/karafka/karafka](https://badges.gitter.im/karafka/karafka.svg)](https://gitter.im/karafka/karafka?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Microframework used to simplify Apache Kafka based Ruby applications development.

## Table of Contents

  - [Table of Contents](#table-of-contents)
  - [How does it work](#how-does-it-work)
  - [Installation](#installation)
  - [Setup](#setup)
    - [Application](#application)
    - [WaterDrop](#waterdrop)
    - [Configurators](#configurators)
    - [Environment variables settings](#environment-variables-settings)
    - [Kafka brokers auto-discovery](#kafka-brokers-auto-discovery)
  - [Usage](#usage)
    - [Karafka CLI](#karafka-cli)
    - [Routing](#routing)
        - [Topic](#topic)
        - [Group](#group)
        - [Worker](#worker)
        - [Parser](#parser)
        - [Interchanger](#interchanger)
    - [Receiving messages](#receiving-messages)
      - [Controllers callbacks](#controllers-callbacks)
    - [Sending messages from Karafka](#sending-messages-from-karafka)
    - [Monitoring and logging](#monitoring-and-logging)
      - [Example monitor with Errbit/Airbrake support](#example-monitor-with-errbit/airbrake-support)
      - [Example monitor with NewRelic support](#example-monitor-with-newrelic-support)
  - [Concurrency](#concurrency)
  - [Sidekiq Web UI](#sidekiq-web-ui)
  - [Integrating with other frameworks](#integrating-with-other-frameworks)
    - [Integrating with Ruby on Rails](#integrating-with-ruby-on-rails)
    - [Integrating with Sinatra](#integrating-with-sinatra)
  - [Articles and other references](#articles-and-other-references)
    - [Libraries and components](#libraries-and-components)
    - [Articles and references](#articles-and-references)
  - [Note on Patches/Pull Requests](#note-on-patches/pull-requests)

## How does it work

Karafka is a microframework to work easier with Apache Kafka incoming messages.

## Installation

Karafka does not have a full installation shell command. In order to install it, please follow given steps:

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

and run Karafka install CLI task:

```
bundle exec karafka install
```

## Setup

### Application
Karafka has following configuration options:

| Option                 | Required | Value type        | Description                                                                                 |
|------------------------|----------|-------------------|---------------------------------------------------------------------------------------------|
| max_concurrency        | true     | Integer           | How many threads maximally should we have that listen for incoming messages                 |
| name                   | true     | String            | Application name                                                                            |
| redis                  | true     | Hash              | Hash with Redis configuration options                                                       |
| wait_timeout           | true     | Integer (Seconds) | How long do we wait for incoming messages on a single socket (topic)                        |
| monitor                | false    | Object            | Monitor instance (defaults to Karafka::Monitor)                                             |
| logger                 | false    | Object            | Logger instance (defaults to Karafka::Logger)                                               |
| zookeeper.hosts        | true     | Array<String>     | Zookeeper server hosts                                                                      |
| kafka.hosts            | false    | Array<String>     | Kafka server hosts - if not provided Karafka will autodiscover them based on Zookeeper data |

To apply this configuration, you need to use a *setup* method from the Karafka::App class (app.rb):

```ruby
class App < Karafka::App
  setup do |config|
    config.zookeeper.hosts =  %w( 127.0.0.1:2181 )
    config.redis = {
      url: 'redis://redis.example.com:7372/1'
    }
    config.wait_timeout = 10 # 10 seconds
    config.max_concurrency = 10 # 10 threads max
    config.name = 'my_application'
    config.logger = MyCustomLogger.new # not required
  end
end
```

Note: You can use any library like [Settingslogic](https://github.com/binarylogic/settingslogic) to handle your application configuration.

### WaterDrop

Karafka contains WaterDrop gem which is used to send messages to Kafka. It is autoconfigured based on the Karafka config.

### Configurators

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

### Environment variables settings

There are several env settings you can use:

| ENV name          | Default | Description                                                                           |
|-------------------|-----------------|-------------------------------------------------------------------------------|
| KARAFKA_ENV       | development     | In what mode this application should boot (production/development/test/etc)   |
| KARAFKA_BOOT_FILE | app_root/app.rb | Path to a file that contains Karafka app configuration and booting procedures |

### Kafka brokers auto-discovery

Karafka supports Kafka brokers auto-discovery during both startup and runtime. It means that **zookeeper_hosts** option allows Karafka to get all the details it needs about Kafka brokers, first during boot and after each failure. If something happens to a connection on which we were listening (or if we cannot connect to a given broker), Karafka will refresh list of available brokers. This allows it to be aware of changes that happen in the infrastructure (adding and removing nodes) and allows it to be up and running as long as Zookeeper is able to provide it all the required information.

## Usage

### Karafka CLI

Karafka has a simple CLI built in. It provides following commands:

| Command        | Description                                                               |
|----------------|---------------------------------------------------------------------------|
| help [COMMAND] | Describe available commands or one specific command                       |
| console        | Start the Karafka console (short-cut alias: "c")                          |
| info           | Print configuration details and other options of your application         |
| install        | Installs all required things for Karafka application in current directory |
| routes         | Print out all defined routes in alphabetical order                        |
| server         | Start the Karafka server (short-cut alias: "s")                           |
| topics         | Lists all topics available on Karafka server (short-cut alias: "t")       |
| worker         | Start the Karafka Sidekiq worker (short-cut alias: "w")                   |

All the commands are executed the same way:

```
bundle exec karafka [COMMAND]
```

### Routing

Prior to version 0.4 Karafka framework didn't have routing. Group, topic and all other "controller related" options were being either taken or initialized directly from the controller. Unfortunately this solution was insufficient. From version 0.4 there's a routing engine.

Routing engine provides an interface to describe how messages from all the topics should be handled. To start using it, just use the *draw* method on routes:

```ruby
App.routes.draw do
  topic :example do
    controller ExampleController
  end
end
```

The basic route description requires providing *topic* and *controller* that should handle it (Karafka will create a separate controller instance for each request).

There are also several other methods available (optional):

  - *group* - symbol/string with a group name. Groups are used to cluster applications
  - *worker* - Class name - name of a worker class that we want to use to schedule perform code
  - *parser* - Class name - name of a parser class that we want to use to parse incoming data
  - *interchanger* - Class name - name of a interchanger class that we want to use to format data that we put/fetch into/from #perform_async

```ruby
App.routes.draw do
  topic :binary_video_details do
    group :composed_application
    controller Videos::DetailsController
    worker Workers::DetailsWorker
    parser Parsers::BinaryToJson
    interchanger Interchangers::Binary
  end

  topic :new_videos do
    controller Videos::NewVideosController
  end
end
```

See description below for more details on each of them.

##### Topic

 - *topic* - symbol/string with a topic that we want to route

```ruby
topic :incoming_messages do
  # Details about how to handle this topic should go here
end
```

Topic is the root point of each route. Keep in mind that:

  - All topic names must be unique in a single Karafka application
  - Topics names are being validated because Kafka does not accept some characters
  - If you don't specify a group, it will be built based on the topic and application name

##### Group

 - *group* - symbol/string with a group name. Groups are used to cluster applications

Optionally you can use **group** method to define group for this topic. Use it if you want to build many applications that will share the same Kafka group. Otherwise it will just build it based on the **topic** and application name. If you're not planning to build applications that will load-balance messages between many different applications (but between one applications many processes), you may want not to define it and allow the framework to define it for you.

```ruby
topic :incoming_messages do
  group :load_balanced_group
  controller MessagesController
end
```

Note that a single group can be used only in a single topic.

##### Worker

 - *worker* - Class name - name of a worker class that we want to use to schedule perform code

Karafka by default will build a worker that will correspond to each of your controllers (so you will have a pair - controller and a worker). All of them will inherit from **ApplicationWorker** and will share all its settings.

To run Sidekiq you should have sidekiq.yml file in *config* folder. The example of sidekiq.yml file will be generated to config/sidekiq.yml.example once you run **bundle exec karafka install**.

However, if you want to use a raw Sidekiq worker (without any Karafka additional magic), or you want to use SidekiqPro (or any other queuing engine that has the same API as Sidekiq), you can assign your own custom worker:

```ruby
topic :incoming_messages do
  controller MessagesController
  worker MyCustomController
end
```

Note that even then, you need to specify a controller that will schedule a background task.

Custom workers need to provide a **#perform_async** method. It needs to accept two arguments:

 - *topic* - first argument is a current topic from which a given message comes
 - *params* - all the params that came from Kafka + additional metadata. This data format might be changed if you use custom interchangers. Otherwise it will be an instance of Karafka::Params::Params.

Keep in mind, that params might be in two states: parsed or unparsed when passed to #perform_async. This means, that if you use custom interchangers and/or custom workers, you might want to look into Karafka's sources to see exactly how it works.

##### Parser

 - *parser* - Class name - name of a parser class that we want to use to parse incoming data

Karafka by default will parse messages with JSON parser. If you want to change this behaviour you need to set custom parser for each route. Parser needs to have a #parse method and raise error that is a ::Karafka::Errors::ParserError descendant when problem appears during parsing process.

```ruby
class XmlParser
  class ParserError < ::Karafka::Errors::ParserError; end

  def self.parse(message)
    Hash.from_xml(message)
  rescue REXML::ParseException
    raise ParserError
  end
end

App.routes.draw do
  topic :binary_video_details do
    controller Videos::DetailsController
    parser XmlParser
  end
end
```

Note that parsing failure won't stop the application flow. Instead, Karafka will assign the raw message inside the :message key of params. That way you can handle raw message inside the Sidekiq worker (you can implement error detection, etc - any "heavy" parsing logic can and should be implemented there).

##### Interchanger

 - *interchanger* - Class name - name of a interchanger class that we want to use to format data that we put/fetch into/from #perform_async.

Custom interchangers target issues with non-standard (binary, etc) data that we want to store when we do #perform_async. This data might be corrupted when fetched in a worker (see [this](https://github.com/karafka/karafka/issues/30) issue). With custom interchangers, you can encode/compress data before it is being passed to scheduling and decode/decompress it when it gets into the worker.

**Warning**: if you decide to use slow interchangers, they might significantly slow down Karafka.

```ruby
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

  topic :binary_video_details do
    controller Videos::DetailsController
    interchanger Base64Interchanger
  end
```

### Receiving messages

Controllers should inherit from **ApplicationController** (or any other controller that inherits from **Karafka::BaseController**). If you don't want to use custom workers (and except some particular cases you don't need to), you need to define a #perform method that will execute your business logic code in background.

```ruby
class UsersController < ApplicationController
  # Method execution will be enqueued in Sidekiq
  # Karafka will schedule automatically a proper job and execute this logic in the background
  def perform
    User.create(params[:user])
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
  class TestController < ApplicationController
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

### Sending messages from Karafka

If you want send messages from karafka you need to use **waterdrop** gem.

Example usage:

```ruby
message = WaterDrop::Message.new('topic', 'message')
message.send!

message = WaterDrop::Message.new('topic', { user_id: 1 }.to_json)
message.send!
```

Please follow [WaterDrop README](https://github.com/karafka/waterdrop/blob/master/README.md) for more details on how to use it.

### Monitoring and logging

Karafka provides a simple monitor (Karafka::Monitor) with a really small API. You can use it to develop your own monitoring system (using for example NewRelic). By default, the only thing that is hooked up to this monitoring is a Karafka logger (Karafka::Logger). It is based on a standard [Ruby logger](http://ruby-doc.org/stdlib-2.2.3/libdoc/logger/rdoc/Logger.html).

To change monitor or a logger assign new logger/monitor during setup:

```ruby
class App < Karafka::App
  setup do |config|
    # Other setup stuff...
    config.logger = MyCustomLogger.new
    config.monitor = CustomMonitor.new
  end
end
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
# NewRelic example monitor for Karafka
class AppMonitor < Karafka::Monitor
  # @param [Class] caller class for this notice
  # @param [Hash] hash with options for this notice
  def notice(caller_class, options = {})
    # Use default Karafka monitor logging
    super
    # Handle differently proper actions that we want to monit with NewRelic
    return unless respond_to?(caller_label, true)
    send(caller_label, options[:topic])
  end

  # @param [Class] caller class for this notice error
  # @param e [Exception] error that happened
  def notice_error(caller_class, e)
    super
    NewRelic::Agent.notice_error(e)
  end

  private

  # Log that messages for a given topic were consumed
  # @param topic [String] topic name
  def consume(topic)
    record_count metric_key(topic, __method__)
  end

  # Log that message for topic were scheduled to be performed async
  # @param topic [String] topic name
  def perform_async(topic)
    record_count metric_key(topic, __method__)
  end

  # Log that message for topic were performed async
  # @param topic [String] topic name
  def perform(topic)
    record_count metric_key(topic, __method__)
  end

  # @param topic [String] topic name
  # @param action [String] action that we want to log (consume/perform_async/perform)
  # @return [String] a proper metric key for NewRelic
  # @example
  #   metric_key('videos', 'perform_async') #=> 'Custom/videos/perform_async'
  def metric_key(topic, action)
    "Custom/#{topic}/#{action}"
  end

  # Records occurence of a given event
  # @param [String] key under which we want to log
  def record_count(key)
    NewRelic::Agent.record_metric(key, count: 1)
  end
end
```

## Concurrency

Karafka uses [Celluloid](https://celluloid.io/) actors to handle listening to incoming connections. Since each topic and group requires a separate connection (which means that we have a connection per controller) we do this concurrently. To prevent Karafka from spawning hundred of threads (in huge application) you can specify concurency level configuration option. If this number matches (or exceeds) your controllers amount, then you will listen to all the topics simultaneously. If it is less then number of controllers, it will use a single thread to check for few topics (one after another). If this value is set to 1, it will just spawn a single thread to check all the sockets one after another.

## Sidekiq Web UI

Karafka comes with a Sidekiq Web UI application that can display the current state of a Sidekiq installation. If you installed Karafka based on the install instructions, you will have a **config.ru** file that allows you to run standalone Puma instance with a Sidekiq Web UI.

To be able to use it (since Karafka does not depend on Puma and Sinatra) add both of them into your Gemfile:

```ruby
gem 'puma'
gem 'sinatra'
```

bundle and run:

```
bundle exec rackup
# Puma starting...
# * Min threads: 0, max threads: 16
# * Environment: development
# * Listening on tcp://localhost:9292
```

You can then navigate to displayer url to check your Sidekiq status. Sidekiq Web UI by default is password protected. To check (or change) your login and password, please review **config.ru** file in your application.

## Integrating with other frameworks

Want to use Karafka with Ruby on Rails or Sinatra? It can be done!

### Integrating with Ruby on Rails

Add Karafka to your Ruby on Rails application Gemfile:

```ruby
gem 'karafka', github: 'karafka/karafka'
```

Copy the **app.rb** file from your Karafka application into your Rails app (if you don't have this file, just create an empty Karafka app and copy it). This file is responsible for booting up Karafka framework. To make it work with Ruby on Rails, you need to load whole Rails application in this file. To do so, replace:

```ruby
ENV['RACK_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] ||= ENV['RACK_ENV']

Bundler.require(:default, ENV['KARAFKA_ENV'])
```

with

```ruby
ENV['RAILS_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] ||= ENV['RAILS_ENV']

require ::File.expand_path('../config/environment', __FILE__)
Rails.application.eager_load!
```

and you are ready to go!

### Integrating with Sinatra

Sinatra applications differ from one another. There are single file applications and apps with similar to Rails structure. That's why we cannot provide a simple single tutorial. Here are some guidelines that you should follow in order to integrate it with Sinatra based application:

Add Karafka to your Sinatra application Gemfile:

```ruby
gem 'karafka', github: 'karafka/karafka'
```

After that make sure that whole your application is loaded before setting up and booting Karafka (see Ruby on Rails integration for more details about that).

## Articles and other references

### Libraries and components

* [Karafka framework](https://github.com/karafka/karafka)
* [Waterdrop](https://github.com/karafka/waterdrop)
* [Worker Glass](https://github.com/karafka/worker-glass)
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
