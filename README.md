![karafka logo](https://raw.githubusercontent.com/karafka/misc/master/logo/karafka_logotype_transparent2.png)

[![Build Status](https://github.com/karafka/karafka/actions/workflows/ci.yml/badge.svg)](https://github.com/karafka/karafka/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/karafka.svg)](http://badge.fury.io/rb/karafka)
[![Join the chat at https://slack.karafka.io](https://raw.githubusercontent.com/karafka/misc/master/slack.svg)](https://slack.karafka.io)

**Note**: All of the documentation here refers to Karafka `2.0.0.rc2` or higher. If you are looking for the documentation for Karafka `1.4`, please click [here](https://github.com/karafka/wiki/tree/1.4).

## About Karafka

Karafka is a multi-threaded framework used to simplify Apache Kafka based Ruby and Ruby on Rails applications development that:

- Supports parallel processing in [multiple threads](Concurrency-and-multithreading) (also for a single topic partition work)
- Has [ActiveJob backend](Active-Job) support (including ordered jobs)
- [Automatically integrates](Integrating-with-Ruby-on-Rails-and-other-frameworks#integrating-with-ruby-on-rails=) with Ruby on Rails
- Supports in-development [code reloading](Auto-reload-of-code-changes-in-development)
- Is powered by [librdkafka](https://github.com/edenhill/librdkafka) (the Apache Kafka C/C++ client library)
- Has an out-of the box [StatsD/DataDog monitoring](Monitoring-and-logging) with a dashboard template.

```ruby
# Define what topics you want to consume with which consumers in karafka.rb
Karafka::App.routes.draw do
  topic 'system_events' do
    consumer EventsConsumer
  end
end

# And create your consumers, within which your messages will be processed
class EventsConsumer < ApplicationConsumer
  # Example that utilizes ActiveRecord#insert_all and Karafka batch processing
  def consume
    # Store all of the incoming Kafka events locally in an efficient way
    Event.insert_all messages.payloads
  end
end
```

Karafka **uses** threads to handle many messages simultaneously in the same process. It does not require Rails but will integrate tightly with any Ruby on Rails applications to make event processing dead simple.

## Getting started

If you're entirely new to the subject, you can start with our "Kafka on Rails" articles series, which will get you up and running with the terminology and basic ideas behind using Kafka:

- [Kafka on Rails: Using Kafka with Ruby on Rails – Part 1 – Kafka basics and its advantages](https://mensfeld.pl/2017/11/kafka-on-rails-using-kafka-with-ruby-on-rails-part-1-kafka-basics-and-its-advantages/)
- [Kafka on Rails: Using Kafka with Ruby on Rails – Part 2 – Getting started with Ruby and Kafka](https://mensfeld.pl/2018/01/kafka-on-rails-using-kafka-with-ruby-on-rails-part-2-getting-started-with-ruby-and-kafka/)

If you want to get started with Kafka and Karafka as fast as possible, then the best idea is to visit our [Getting started](https://github.com/karafka/karafka/wiki/Getting-started) guides and the [example apps repository](https://github.com/karafka/example-apps).

We also maintain many [integration specs](https://github.com/karafka/karafka/tree/master/spec/integrations) illustrating various use-cases and features of the framework.

### TL;DR (1 minute from setup to publishing and consuming messages)

**Prerequisites**: Kafka running. You can start it by following instructions from [here](https://github.com/karafka/karafka/wiki/Setting-up-Kafka).

1. Add and install Karafka:

```bash
bundle add karafka -v 2.0.0.rc2

bundle exec karafka install
```

2. Dispatch a message to the example topic using the Rails or Ruby console:

```ruby
Karafka.producer.produce_sync(topic: 'example', payload: { 'ping' => 'pong' }.to_json)
```

3. Run karafka and see the consumption magic happen:

```ruby
bundle exec karafka server

[7616dc24-505a-417f-b87b-6bf8fc2d98c5] Polling messages...
[7616dc24-505a-417f-b87b-6bf8fc2d98c5] Polled 1 message in 5001ms
[dcf3a8d8-0bd9-433a-8f63-b70a0cdb0732] Consume job for ExampleConsumer on example started
{"ping"=>"pong"}
```

## Want to Upgrade? LGPL is not for you? Want to help?

I also sell Karafka Pro subscriptions. It includes a commercial-friendly license, priority support, architecture consultations, and high throughput data processing-related features (virtual partitions, long-running jobs, and more).

**20%** of the income will be distributed back to other OSS projects that Karafka uses under the hood.

Help me provide high-quality open-source software. Please see the Karafka [homepage](https://karafka.io) for more details.

## Support

Karafka has [Wiki pages](https://github.com/karafka/karafka/wiki) for almost everything and a pretty decent [FAQ](https://github.com/karafka/karafka/wiki/FAQ). It covers the installation, setup, and deployment, along with other useful details on how to run Karafka.

If you have questions about using Karafka, feel free to join our [Slack](https://slack.karafka.io) channel.

Karafka has priority support for technical and architectural questions that is part of the Karafka Pro subscription.
