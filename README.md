# Karafka

[![Build Status](https://travis-ci.org/karafka/karafka.png)](https://travis-ci.org/karafka/karafka)

Microframework used to simplify Kafka based Ruby applications

## Setup

Karafka has following configuration options:

| Option                  | Value type    | Description                    |
|-------------------------|---------------|--------------------------------|
| zookeeper_hosts         | Array<String> | Zookeeper server hosts         |
| kafka_hosts             | Array<String> | Kafka server hosts             |

To apply this configuration, you need to use a *configure* method:

```ruby
Karafka.configure do |config|
  config.kafka_hosts = %w( 127.0.0.1:9092 127.0.0.1:9093 )
  config.zookeeper_hosts =  %w( 127.0.0.1:2181 )
end
```
This configuration can be placed in *config/initializers*.