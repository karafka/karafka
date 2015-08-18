# Karafka

[![Build Status](https://travis-ci.org/karafka/karafka.png)](https://travis-ci.org/karafka/karafka)

Microframework used to simplify Kafka based Ruby applications

## How it works

Karafka is a microframework to work easier with Kafka incoming events.

## Setup

Karafka has following configuration options:

| Option                  | Value type    | Description                    |
|-------------------------|---------------|--------------------------------|
| zookeeper_hosts         | Array<String> | Zookeeper server hosts         |
| kafka_hosts             | Array<String> | Kafka server hosts             |

To apply this configuration, you need to use a *setup* method from the Karafka::App class:

```ruby
class App < Karafka::App
  setup do |config|
    config.kafka_hosts = %w( 127.0.0.1:9092 127.0.0.1:9093 )
    config.zookeeper_hosts =  %w( 127.0.0.1:2181 )
  end
end

```

## Sending events from Karafka

To add ability to send events you need add **waterdrop** gem to your Gemfile.

Please follow [WaterDrop README](https://github.com/karafka/waterdrop/blob/master/README.md) for more details on how to install and use it.
