# Karafka

[![Build Status](https://travis-ci.org/karafka/karafka.png)](https://travis-ci.org/karafka/karafka)
[![Code Climate](https://codeclimate.com/github/karafka/karafka/badges/gpa.svg)](https://codeclimate.com/github/karafka/karafka)
[![Join the chat at https://gitter.im/karafka/karafka](https://badges.gitter.im/karafka/karafka.svg)](https://gitter.im/karafka/karafka?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Framework used to simplify Apache Kafka based Ruby applications development.

It allows programmers to use approach similar to "the Rails way" when working with asynchronous Kafka messages.

Karafka not only handles incoming messages but also provides tools for building complex data-flow applications that receive and send messages.

## Table of Contents

  - [Table of Contents](#table-of-contents)
  - [Support](#support)
  - [Requirements](#requirements)
  - [How does it work](#how-does-it-work)
  - [Installation](#installation)
  - [Setup](#setup)
    - [Application](#application)
    - [Configurators](#configurators)
    - [Environment variables settings](#environment-variables-settings)
    - [Kafka brokers auto-discovery](#kafka-brokers-auto-discovery)
    - [Topic mappers](#topic-mappers)
  - [Usage](#usage)
    - [Karafka CLI](#karafka-cli)
    - [Routing](#routing)
        - [Topic](#topic)
        - [Group](#group)
        - [Worker](#worker)
        - [Parser](#parser)
        - [Interchanger](#interchanger)
        - [Responder](#responder)
        - [Inline mode flag](#inline-mode-flag)
        - [Batch mode flag](#batch-mode-flag)
    - [Receiving messages](#receiving-messages)
        - [Processing messages directly (without Sidekiq)](#processing-messages-directly-without-sidekiq)
    - [Sending messages from Karafka](#sending-messages-from-karafka)
        - [Using responders (recommended)](#using-responders-recommended)
        - [Using WaterDrop directly](#using-waterdrop-directly)
  - [Important components](#important-components)
    - [Controllers](#controllers)
        - [Controllers callbacks](#controllers-callbacks)
        - [Dynamic worker selection](#dynamic-worker-selection)
    - [Responders](#responders)
        - [Registering topics](#registering-topics)
        - [Responding on topics](#responding-on-topics)
        - [Response validation](#response-validation)
        - [Response partitioning](#response-partitioning)
  - [Monitoring and logging](#monitoring-and-logging)
      - [Example monitor with Errbit/Airbrake support](#example-monitor-with-errbitairbrake-support)
      - [Example monitor with NewRelic support](#example-monitor-with-newrelic-support)
  - [Deployment](#deployment)
      - [Capistrano](#capistrano)
      - [Docker](#docker)
  - [Sidekiq Web UI](#sidekiq-web-ui)
  - [Concurrency](#concurrency)
  - [Integrating with other frameworks](#integrating-with-other-frameworks)
      - [Integrating with Ruby on Rails](#integrating-with-ruby-on-rails)
      - [Integrating with Sinatra](#integrating-with-sinatra)
  - [Articles and other references](#articles-and-other-references)
      - [Libraries and components](#libraries-and-components)
      - [Articles and references](#articles-and-references)
  - [Note on Patches/Pull Requests](#note-on-patchespull-requests)

## How does it work

Karafka provides a higher-level abstraction than raw Kafka Ruby drivers, such as Kafka-Ruby and Poseidon. Instead of focusing on  single topic consumption, it provides developers with a set of tools that are dedicated for building multi-topic applications similarly to how Rails applications are being built.

## Support

If you have any questions about using Karafka, feel free to join our [Gitter](https://gitter.im/karafka/karafka) chat channel.

## Requirements

In order to use Karafka framework, you need to have:

  - Zookeeper (required by Kafka)
  - Kafka (at least 0.9.0)
  - Ruby (at least 2.3.0)

## Installation

Karafka does not have a full installation shell command. In order to install it, please follow the below steps:

Create a directory for your project:

```bash
mkdir app_dir
cd app_dir
```

Create a **Gemfile** with Karafka:

```ruby
source 'https://rubygems.org'

gem 'karafka'
```

and run Karafka install CLI task:

```
bundle exec karafka install
```

## Setup

### Application
Karafka has following configuration options:

| Option                        | Required | Value type        | Description                                                                                                |
|-------------------------------|----------|-------------------|------------------------------------------------------------------------------------------------------------|
| name                          | true     | String            | Application name                                                                                           |
| topic_mapper                  | false    | Class/Module      | Mapper for hiding Kafka provider specific topic prefixes/postfixes, so internaly we use "pure" topics      |
| redis                         | false    | Hash              | Hash with Redis configuration options. It is required if inline_mode is off.                               |
| inline_mode                   | false    | Boolean           | Do we want to perform logic without enqueuing it with Sidekiq (directly and asap)                          |
| batch_mode                    | false    | Boolean           | Should the incoming messages be consumed in batches, or one at a time                                      |
| start_from_beginning          | false    | Boolean           | Consume messages starting at the beginning or consume new messages that are produced at first run          |
| monitor                       | false    | Object            | Monitor instance (defaults to Karafka::Monitor)                                                            |
| logger                        | false    | Object            | Logger instance (defaults to Karafka::Logger)                                                              |
| kafka.hosts                   | true     | Array<String>     | Kafka server hosts. If 1 provided, Karafka will discover cluster structure automatically                   |
| kafka.session_timeout         | false    | Integer           | The number of seconds after which, if a consumer hasn't contacted the Kafka cluster, it will be kicked out |
| kafka.offset_commit_interval  | false    | Integer           | The interval between offset commits in seconds                                                             |
| kafka.offset_commit_threshold | false    | Integer           | The number of messages that can be processed before their offsets are committed                            |
| kafka.heartbeat_interval      | false    | Integer           | The interval between heartbeats                                                                            |
| kafka.ssl.ca_cert             | false    | String            | SSL CA certificate                                                                                         |
| kafka.ssl.client_cert         | false    | String            | SSL client certificate                                                                                     |
| kafka.ssl.client_cert_key     | false    | String            | SSL client certificate password                                                                            |
| connection_pool.size          | false    | Integer           | Connection pool size for message producers connection pool                                                 |
| connection_pool.timeout       | false    | Integer           | Connection pool timeout for message producers connection pool                                              |

To apply this configuration, you need to use a *setup* method from the Karafka::App class (app.rb):

```ruby
class App < Karafka::App
  setup do |config|
    config.kafka.hosts = %w( 127.0.0.1:9092 )
    config.inline_mode = false
    config.batch_mode = false
    config.redis = {
      url: 'redis://redis.example.com:7372/1'
    }
    config.name = 'my_application'
    config.logger = MyCustomLogger.new # not required
  end
end
```

Note: You can use any library like [Settingslogic](https://github.com/binarylogic/settingslogic) to handle your application configuration.

### Configurators

For additional setup and/or configuration tasks you can create custom configurators. Similar to Rails these are added to a `config/initializers` directory and run after app initialization.

Your new configurator class must inherit from `Karafka::Setup::Configurators::Base` and implement a `setup` method.

Example configuration class:

```ruby
class ExampleConfigurator < Karafka::Setup::Configurators::Base
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

Karafka supports Kafka brokers auto-discovery during startup and on failures. You need to provide at least one Kafka broker, from which the entire Kafka cluster will be discovered. Karafka will refresh list of available brokers if something goes wrong. This allows it to be aware of changes that happen in the infrastructure (adding and removing nodes).

### Topic mappers

Some Kafka cloud providers require topics to be namespaced with user name. This approach is understandable, but at the same time, makes your applications less provider agnostic. To target that issue, you can create your own topic mapper that will sanitize incoming/outgoing topic names, so your logic won't be binded to those specific versions of topic names.

Mapper needs to implement two following methods:

  - ```#incoming``` - accepts an incoming "namespace dirty" version ot topic. Needs to return sanitized topic.
  - ```#outgoing``` - accepts outgoing sanitized topic version. Needs to return namespaced one.

Given each of the topics needs to have "karafka." prefix, your mapper could look like that:

```ruby
class KarafkaTopicMapper
  def initialize(prefix)
    @prefix = prefix
  end

  def incoming(topic)
    topic.to_s.gsub("#{@prefix}.", '')
  end

  def outgoing(topic)
    "#{@prefix}.#{topic}"
  end
end

mapper = KarafkaTopicMapper.new('karafka')
mapper.incoming('karafka.my_super_topic') #=> 'my_super_topic'
mapper.outgoing('my_other_topic') #=> 'karafka.my_other_topic'
```

To use custom mapper, just assign it during application configuration:

```ruby
class App < Karafka::App
  setup do |config|
    # Other settings
    config.topic_mapper = MyCustomMapper.new('username')
  end
end
```

Topic mapper automatically integrates with both messages consumer and responders.

## Usage

### Karafka CLI

Karafka has a simple CLI built in. It provides following commands:

| Command        | Description                                                               |
|----------------|---------------------------------------------------------------------------|
| help [COMMAND] | Describe available commands or one specific command                       |
| console        | Start the Karafka console (short-cut alias: "c")                          |
| flow           | Print application data flow (incoming => outgoing)                        |
| info           | Print configuration details and other options of your application         |
| install        | Installs all required things for Karafka application in current directory |
| routes         | Print out all defined routes in alphabetical order                        |
| server         | Start the Karafka server (short-cut alias: "s")                           |
| worker         | Start the Karafka Sidekiq worker (short-cut alias: "w")                   |

All the commands are executed the same way:

```
bundle exec karafka [COMMAND]
```

If you need more details about each of the CLI commands, you can execute following command:

```
  bundle exec karafka help [COMMAND]
```

### Routing

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
  - *interchanger* - Class name - name of a interchanger class that we want to use to format data that we put/fetch into/from *#perform_async*
  - *responder* - Class name - name of a responder that we want to use to generate responses to other Kafka topics based on our processed data
  - *inline_mode* - Boolean - Do we want to perform logic without enqueuing it with Sidekiq (directly and asap) - overwrites global app setting
  - *batch_mode* - Boolean - Handle the incoming messages in batch, or one at a time - overwrites global app setting

```ruby
App.routes.draw do
  topic :binary_video_details do
    group :composed_application
    controller Videos::DetailsController
    worker Workers::DetailsWorker
    parser Parsers::BinaryToJson
    interchanger Interchangers::Binary
    responder BinaryVideoProcessingResponder
    inline_mode true
    batch_mode true
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
  worker MyCustomWorker
end
```

Note that even then, you need to specify a controller that will schedule a background task.

Custom workers need to provide a **#perform_async** method. It needs to accept two arguments:

 - *topic* - first argument is a current topic from which a given message comes
 - *params* - all the params that came from Kafka + additional metadata. This data format might be changed if you use custom interchangers. Otherwise it will be an instance of Karafka::Params::Params.

Keep in mind, that params might be in two states: parsed or unparsed when passed to #perform_async. This means, that if you use custom interchangers and/or custom workers, you might want to look into Karafka's sources to see exactly how it works.

##### Parser

 - *parser* - Class name - name of a parser class that we want to use to serialize and deserialize incoming and outgoing data.

Karafka by default will parse messages with a Json parser. If you want to change this behaviour you need to set a custom parser for each route. Parser needs to have a following class methods:

  - *parse* - method used to parse incoming string into an object/hash
  - *generate* - method used in responders in order to convert objects into strings that have desired format

and raise an error that is a ::Karafka::Errors::ParserError descendant when problem appears during the parsing process.

```ruby
class XmlParser
  class ParserError < ::Karafka::Errors::ParserError; end

  def self.parse(message)
    Hash.from_xml(message)
  rescue REXML::ParseException
    raise ParserError
  end

  def self.generate(object)
    object.to_xml
  end
end

App.routes.draw do
  topic :binary_video_details do
    controller Videos::DetailsController
    parser XmlParser
  end
end
```

Note that parsing failure won't stop the application flow. Instead, Karafka will assign the raw message inside the :message key of params. That way you can handle raw message inside the Sidekiq worker (you can implement error detection, etc. - any "heavy" parsing logic can and should be implemented there).

##### Interchanger

 - *interchanger* - Class name - name of an interchanger class that we want to use to format data that we put/fetch into/from #perform_async.

Custom interchangers target issues with non-standard (binary, etc.) data that we want to store when we do #perform_async. This data might be corrupted when fetched in a worker (see [this](https://github.com/karafka/karafka/issues/30) issue). With custom interchangers, you can encode/compress data before it is being passed to scheduling and decode/decompress it when it gets into the worker.

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

##### Responder

  - *responder* - Class name - name of a responder that we want to use to generate responses to other Kafka topics based on our processed data.

Responders are used to design the response that should be generated and sent to proper Kafka topics, once processing is done. It allows programmers to build not only data-consuming apps, but to build apps that consume data and, then, based on the business logic output send this processed data onwards (similarly to how Bash pipelines work).

```ruby
class Responder < ApplicationResponder
  topic :users_created
  topic :profiles_created

  def respond(user, profile)
    respond_to :users_created, user
    respond_to :profiles_created, profile
  end
end
```

For more details about responders, please go to the [using responders](#using-responders) section.

##### Inline mode flag

Inline mode flag allows you to disable Sidekiq usage by performing your #perform method business logic in the main Karafka server process.

This flag be useful when you want to:

  - process messages one by one in a single flow
  - process messages as soon as possible (without Sidekiq delay)

Note: Keep in mind, that by using this, you can significantly slow down Karafka. You also loose all the advantages of Sidekiq processing (reentrancy, retries, etc).

##### Batch mode flag

Batch mode allows you to increase the overall throughput of your kafka consumer by handling incoming messages in batches, instead of one at a time.

Note: The downside of increasing throughput is a slight increase in latency. Also keep in mind, that the client commits the offset of the batch's messages only **after** the entire batch has been scheduled into Sidekiq (or processed in case of inline mode).

### Receiving messages

Karafka framework has a long running server process that is responsible for receiving messages.

To start Karafka server process, use the following CLI command:

```bash
bundle exec karafka server
```

Karafka server can be daemonized with the **--daemon** flag:

```
bundle exec karafka server --daemon
```

#### Processing messages directly (without Sidekiq)

If you don't want to use Sidekiq for processing and you would rather process messages directly in the main Karafka server process, you can do that by setting the *inline* flag either on an app level:

```ruby
class App < Karafka::App
  setup do |config|
    config.inline_mode = true
    # Rest of the config
  end
end
```

or per route (when you want to treat some routes in a different way):

```ruby
App.routes.draw do
  topic :binary_video_details do
    controller Videos::DetailsController
    inline_mode true
  end
end
```

Note: it can slow Karafka down significantly if you do heavy stuff that way.

### Sending messages from Karafka

It's quite common when using Kafka, to treat applications as parts of a bigger pipeline (similary to Bash pipeline) and forward processing results to other applications. Karafka provides two ways of dealing with that:

  - Using responders
  - Using Waterdrop directly

Each of them has it's own advantages and disadvantages and it strongly depends on your application business logic which one will be better. The recommended (and way more elegant) way is to use responders for that.

#### Using responders (recommended)

One of the main differences when you respond to a Kafka message instead of a HTTP response, is that the response can be sent to many topics (instead of one HTTP response per one request) and that the data that is being sent can be different for different topics. That's why a simple **respond_to** would not be enough.

In order to go beyond this limitation, Karafka uses responder objects that are responsible for sending data to other Kafka topics.

By default, if you name a responder with the same name as a controller, it will be detected automatically:

```ruby
module Users
  class CreateController < ApplicationController
    def perform
      # You can provide as many objects as you want to respond_with as long as a responders
      # #respond method accepts the same amount
      respond_with User.create(params[:user])
    end
  end

  class CreateResponder < ApplicationResponder
    topic :user_created

    def respond(user)
      respond_to :user_created, user
    end
  end
end
```

The appropriate responder will be used automatically when you invoke the **respond_with** controller method.

Why did we separate the response layer from the controller layer? Because sometimes when you respond to multiple topics conditionally, that logic can be really complex and it is way better to manage and test it in isolation.

For more details about responders DSL, please visit the [responders](#responders) section.

#### Using WaterDrop directly

It is not recommended (as it breaks responders validations and makes it harder to track data flow), but if you want to send messages outside of Karafka responders, you can to use the **waterdrop** gem directly.

Example usage:

```ruby
message = WaterDrop::Message.new('topic', 'message')
message.send!

message = WaterDrop::Message.new('topic', { user_id: 1 }.to_json)
message.send!
```

Please follow [WaterDrop README](https://github.com/karafka/waterdrop/blob/master/README.md) for more details on how to use it.


## Important components

Apart from the internal implementation, Karafka is combined from the following components  programmers mostly will work with:

  - Controllers - objects that are responsible for processing incoming messages (similar to Rails controllers)
  - Responders - objects that are responsible for sending responses based on the processed data
  - Workers - objects that execute data processing using Sidekiq backend

### Controllers

Controllers should inherit from **ApplicationController** (or any other controller that inherits from **Karafka::BaseController**). If you don't want to use custom workers (and except some particular cases you don't need to), you need to define a **#perform** method that will execute your business logic code in background.

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

You can add any number of *before_enqueue* callbacks. It can be a method or a block.
before_enqueue acts in a similar way to Rails before_action so it should perform "lightweight" operations. You have access to params inside. Based on them you can define which data you want to receive and which you do not.

**Warning**: keep in mind, that all *before_enqueue* blocks/methods are executed after messages are received. This is not executed in Sidekiq, but right after receiving the incoming message. This means, that if you perform "heavy duty" operations there, Karafka might slow down significantly.

If any of callbacks throws :abort - *perform* method will be not enqueued to the worker (the execution chain will stop).

Once you run a consumer - messages from Kafka server will be send to a proper controller (based on topic name).

Presented example controller will accept incoming messages from a Kafka topic named :karafka_topic

```ruby
  class TestController < ApplicationController
    # before_enqueue has access to received params.
    # You can modify them before enqueuing it to sidekiq.
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
     throw(:abort) unless params['message'].to_i > 50 && params['method'] != 'sum'
   end
end
```

#### Dynamic worker selection

When you work with Karafka, you may want to schedule part of the jobs to a different worker based on the incoming params. This can be achieved by reassigning worker in the *#before_enqueue* block:

```ruby
before_enqueue do
  self.worker = (params[:important] ? FastWorker : SlowWorker)
end
```


### Responders

Responders are used to design and control response flow that comes from a single controller action. You might be familiar with a #respond_with Rails controller method. In Karafka it is an entrypoint to a responder *#respond*.

Having a responders layer helps you prevent bugs when you design a receive-respond applications that handle multiple incoming and outgoing topics. Responders also provide a security layer that allows you to control that the flow is as you intended. It will raise an exception if you didn't respond to all the topics that you wanted to respond to.

Here's a simple responder example:

```ruby
class ExampleResponder < ApplicationResponder
  topic :users_notified

  def respond(user)
    respond_to :users_notified, user
  end
end
```

When passing data back to Kafka, responder uses parser **#generate** method to convert message object to a string. It will use parser of a route for which a current message was directed. By default it uses Karafka::Parsers::Json parser.

Note: You can use responders outside of controllers scope, however it is not recommended because then, they won't be listed when executing **karafka flow** CLI command.

#### Registering topics

In order to maintain order in topics organization, before you can send data to a given topic, you need to register it. To do that, just execute *#topic* method with a topic name and optional settings during responder initialization:

```ruby
class ExampleResponder < ApplicationResponder
  topic :regular_topic
  topic :optional_topic, required: false
  topic :multiple_use_topic, multiple_usage: true
end
```

*#topic* method accepts following settings:

| Option         | Type    | Default | Description                                                                                                |
|----------------|---------|---------|------------------------------------------------------------------------------------------------------------|
| required       | Boolean | true    | Should we raise an error when a topic was not used (if required)                                           |
| multiple_usage | Boolean | false   | Should we raise an error when during a single response flow we sent more than one message to a given topic |

#### Responding on topics

When you receive a single HTTP request, you generate a single HTTP response. This logic does not apply to Karafka. You can respond on as many topics as you want (or on none).

To handle responding, you need to define *#respond* instance method. This method should accept the same amount of arguments passed into *#respond_with* method.

In order to send a message to a given topic, you have to use **#respond_to** method that accepts two arguments:

  - topic name (Symbol)
  - data you want to send (if data is not string, responder will try to run #to_json method on the incoming data)

```ruby
# respond_with user, profile

class ExampleResponder < ApplicationResponder
  topic :regular_topic
  topic :optional_topic, required: false

  def respond(user, profile)
    respond_to :regular_topic, user

    if user.registered?
      respond_to :optional_topic, profile
    end
  end
end
```

#### Response validation

In order to ensure the dataflow is as intended, responder will validate what and where was sent, making sure that:

  - Only topics that were registered were used (no typos, etc.)
  - Only a single message was sent to a topic that was registered without a **multiple_usage** flag
  - Any topic that was registered with **required** flag (default behavior) has been used

This is an automatic process and does not require any triggers.

#### Response partitioning

Kafka topics are partitioned, which means that  you can assing messages to partitions based on your business logic. To do so from responders, you can pass one of the following keyword arguments as a last option of a **#respond_to** method:

* partition - use it when you want to send a given message to a certain partition
* partition_key - use it when you want to ensure that a certain group of messages is delivered to the same partition, but you don't which partition it will be.

```ruby
class ExampleResponder < ApplicationResponder
  topic :regular_topic
  topic :different_topic

  def respond(user, profile)
    respond_to :regular_topic, user, partition: 12
    # This will send user details to a partition based on the first letter
    # of login which means that for example all users with login starting
    # with "a" will go to the same partition on the different_topic
    respond_to :different_topic, user, partition_key: user.login[0].downcase
  end
end
```

If no keys are passed, the producer will randomly assign a partition.

## Monitoring and logging

Karafka provides a simple monitor (Karafka::Monitor) with a really small API. You can use it to develop your own monitoring system (using for example NewRelic). By default, the only thing that is hooked up to this monitoring is a Karafka logger (Karafka::Logger). It is based on a standard [Ruby logger](http://ruby-doc.org/stdlib-2.2.3/libdoc/logger/rdoc/Logger.html).

To change monitor or a logger assign new logger/monitor during setup:

```ruby
class App < Karafka::App
  setup do |config|
    # Other setup stuff...
    config.logger = MyCustomLogger.new
    config.monitor = CustomMonitor.instance
  end
end
```

Keep in mind, that if you replace monitor with a custom one, you will have to implement logging as well. It is because monitoring is used for both monitoring and logging and a default monitor handles logging as well.

### Example monitor with Errbit/Airbrake support

Here's a simple example of monitor that is used to handle errors logging into Airbrake/Errbit.

```ruby
class AppMonitor < Karafka::Monitor
  def notice_error(caller_class, e)
    super
    Airbrake.notify(e)
  end
end
```

### Example monitor with NewRelic support

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

  # Log that message for a given topic was consumed
  # @param topic [String] topic name
  def consume(topic)
    record_count metric_key(topic, __method__)
  end

  # Log that message for topic was scheduled to be performed async
  # @param topic [String] topic name
  def perform_async(topic)
    record_count metric_key(topic, __method__)
  end

  # Log that message for topic was performed async
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

## Deployment

Karafka is currently being used in production with following deployment methods:

  - Capistrano
  - Docker

Since the only thing that is long-running is Karafka server, it should't be hard to make it work with other deployment and CD tools.

### Capistrano

For details about integration with Capistrano, please go to [capistrano-karafka](https://github.com/karafka/capistrano-karafka) gem page.

### Docker

Karafka can be dockerized as any other Ruby/Rails app. To execute **karafka server** command in your Docker container, just put this into your Dockerfile:

```bash
ENV KARAFKA_ENV production
CMD bundle exec karafka server
```

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

## Concurrency

Karafka uses [Celluloid](https://celluloid.io/) actors to handle listening to incoming connections. Since each topic and group requires a separate connection (which means that we have a connection per controller) we do this concurrently. It means, that for each route, you will have one additional thread running.

## Integrating with other frameworks

Want to use Karafka with Ruby on Rails or Sinatra? It can be done!

### Integrating with Ruby on Rails

Add Karafka to your Ruby on Rails application Gemfile:

```ruby
gem 'karafka'
```

Copy the **app.rb** file from your Karafka application into your Rails app (if you don't have this file, just create an empty Karafka app and copy it). This file is responsible for booting up Karafka framework. To make it work with Ruby on Rails, you need to load whole Rails application in this file. To do so, replace:

```ruby
ENV['RACK_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] = ENV['RACK_ENV']

Bundler.require(:default, ENV['KARAFKA_ENV'])

Karafka::Loader.new.load(Karafka::App.root)
```

with

```ruby
ENV['RAILS_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] = ENV['RAILS_ENV']

require ::File.expand_path('../config/environment', __FILE__)
Rails.application.eager_load!
```

and you are ready to go!

### Integrating with Sinatra

Sinatra applications differ from one another. There are single file applications and apps with similar to Rails structure. That's why we cannot provide a simple single tutorial. Here are some guidelines that you should follow in order to integrate it with Sinatra based application:

Add Karafka to your Sinatra application Gemfile:

```ruby
gem 'karafka'
```

After that make sure that whole your application is loaded before setting up and booting Karafka (see Ruby on Rails integration for more details about that).

## Articles and other references

### Libraries and components

* [Karafka framework](https://github.com/karafka/karafka)
* [Capistrano Karafka](https://github.com/karafka/capistrano-karafka)
* [Waterdrop](https://github.com/karafka/waterdrop)
* [Worker Glass](https://github.com/karafka/worker-glass)
* [Envlogic](https://github.com/karafka/envlogic)
* [Apache Kafka](http://kafka.apache.org/)
* [Apache ZooKeeper](https://zookeeper.apache.org/)
* [Ruby-Kafka](https://github.com/zendesk/ruby-kafka)

### Articles and references

* [Karafka (Ruby + Kafka framework) 0.5.0 release details](http://dev.mensfeld.pl/2016/09/karafka-ruby-kafka-framework-0-5-0-release-details/)
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
