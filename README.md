# Karafka

[![Build Status](https://travis-ci.org/karafka/karafka.png)](https://travis-ci.org/karafka/karafka)

Microframework used to simplify Kafka based Ruby applications

## Setup

Karafka has following configuration options:

| Option                  | Value type    | Description                    |
|-------------------------|---------------|--------------------------------|
| zookeeper_hosts         | Array<String> | Zookeeper server hosts         |
| kafka_hosts             | Array<String> | Kafka server hosts             |

To apply this configuration, you need to use a *setup* method:

```ruby
Karafka.setup do |config|
  config.kafka_hosts = %w( 127.0.0.1:9092 127.0.0.1:9093 )
  config.zookeeper_hosts =  %w( 127.0.0.1:2181 )
end
```
This configuration can be placed in *config/initializers*.

To has ability to send messages as well you should install
[WaterDrop](https://github.com/karafka/waterdrop) gem.
After you should setup it with following options

| Option                  | Value type    | Description                    |
|-------------------------|---------------|--------------------------------|
| send_events             | Boolean       | Should we send events to Kafka |
| kafka_host              | String        | Kafka server host              |
| kafka_ports             | Array<String> | Kafka server ports             |
| connection_pool_size    | Integer       | Kafka connection pool size     |
| connection_pool_timeout | Integer       | Kafka connection pool timeout  |

To apply this configuration, you need to use a *setup* method:

```ruby
WaterDrop.setup do |config|
  config.send_events = true
  config.connection_pool_size = 20
  config.connection_pool_timeout = 1
  config.kafka_ports = %w( 9092 )
  config.kafka_host = 'localhost'
end
```