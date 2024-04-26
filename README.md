![karafka logo](https://raw.githubusercontent.com/karafka/misc/master/logo/karafka_logotype_transparent2.png)

[![Build Status](https://github.com/karafka/karafka/actions/workflows/ci.yml/badge.svg)](https://github.com/karafka/karafka/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/karafka.svg)](http://badge.fury.io/rb/karafka)
[![Join the chat at https://slack.karafka.io](https://raw.githubusercontent.com/karafka/misc/master/slack.svg)](https://slack.karafka.io)

## About Karafka

Karafka is a Ruby and Rails multi-threaded efficient Kafka processing framework that:

- Has a built-in [Web UI](https://karafka.io/docs/Web-UI-Features/) providing a convenient way to monitor and manage Karafka-based applications.
- Supports parallel processing in [multiple threads](https://karafka.io/docs/Concurrency-and-multithreading) (also for a [single topic partition](https://karafka.io/docs/Pro-Virtual-Partitions) work) and [processes](https://karafka.io/docs/Swarm-Multi-Process).
- [Automatically integrates](https://karafka.io/docs/Integrating-with-Ruby-on-Rails-and-other-frameworks#integrating-with-ruby-on-rails) with Ruby on Rails
- Has [ActiveJob backend](https://karafka.io/docs/Active-Job) support (including [ordered jobs](https://karafka.io/docs/Pro-Enhanced-Active-Job#ordered-jobs))
- Has a seamless [Dead Letter Queue](https://karafka.io/docs/Dead-Letter-Queue/) functionality built-in
- Supports in-development [code reloading](https://karafka.io/docs/Auto-reload-of-code-changes-in-development)
- Is powered by [librdkafka](https://github.com/edenhill/librdkafka) (the Apache Kafka C/C++ client library)
- Has an out-of the box [AppSignal](https://karafka.io/docs/Monitoring-and-Logging/#appsignal-metrics-and-error-tracking) and [StatsD/DataDog](https://karafka.io/docs/Monitoring-and-Logging/#datadog-and-statsd-integration) monitoring with dashboard templates.

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

![karafka web ui](https://raw.githubusercontent.com/karafka/misc/master/printscreens/web-ui.png)

If you're entirely new to the subject, you can start with our "Kafka on Rails" articles series, which will get you up and running with the terminology and basic ideas behind using Kafka:

- [Kafka on Rails: Using Kafka with Ruby on Rails – Part 1 – Kafka basics and its advantages](https://mensfeld.pl/2017/11/kafka-on-rails-using-kafka-with-ruby-on-rails-part-1-kafka-basics-and-its-advantages/)
- [Kafka on Rails: Using Kafka with Ruby on Rails – Part 2 – Getting started with Rails and Kafka](https://mensfeld.pl/2018/01/kafka-on-rails-using-kafka-with-ruby-on-rails-part-2-getting-started-with-ruby-and-kafka/)

If you want to get started with Kafka and Karafka as fast as possible, then the best idea is to visit our [Getting started](https://karafka.io/docs/Getting-Started) guides and the [example apps repository](https://github.com/karafka/example-apps).

We also maintain many [integration specs](https://github.com/karafka/karafka/tree/master/spec/integrations) illustrating various use-cases and features of the framework.

### TL;DR (1 minute from setup to publishing and consuming messages)

**Prerequisites**: Kafka running. You can start it by following instructions from [here](https://karafka.io/docs/Setting-up-Kafka).

1. Add and install Karafka:

```bash
# Make sure to install Karafka 2.4
bundle add karafka --version ">= 2.4.0"

bundle exec karafka install
```

2. Dispatch a message to the example topic using the Rails or Ruby console:

```ruby
Karafka.producer.produce_sync(topic: 'example', payload: { 'ping' => 'pong' }.to_json)
```

3. Run Karafka server and see the consumption magic happen:

```bash
bundle exec karafka server

[86d47f0b92f7] Polled 1 message in 1000ms
[3732873c8a74] Consume job for ExampleConsumer on example started
{"ping"=>"pong"}
[3732873c8a74] Consume job for ExampleConsumer on example finished in 0ms
```

## Want to Upgrade? LGPL is not for you? Want to help?

I also sell Karafka Pro subscriptions. It includes a commercial-friendly license, priority support, architecture consultations, enhanced Web UI and high throughput data processing-related features (virtual partitions, long-running jobs, and more).

**10%** of the income will be distributed back to other OSS projects that Karafka uses under the hood.

Help me provide high-quality open-source software. Please see the Karafka [homepage](https://karafka.io/#become-pro) for more details.

## Support

Karafka has [Wiki pages](https://karafka.io/docs) for almost everything and a pretty decent [FAQ](https://karafka.io/docs/FAQ). It covers the installation, setup, and deployment, along with other useful details on how to run Karafka.

If you have questions about using Karafka, feel free to join our [Slack](https://slack.karafka.io) channel.

Karafka has [priority support](https://karafka.io/docs/Pro-Support) for technical and architectural questions that is part of the Karafka Pro subscription.
