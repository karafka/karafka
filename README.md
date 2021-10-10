![karafka logo](https://raw.githubusercontent.com/karafka/misc/master/logo/karafka_logotype_transparent2.png)

[![Build Status](https://github.com/karafka/karafka/actions/workflows/ci.yml/badge.svg)](https://github.com/karafka/karafka/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/karafka.svg)](http://badge.fury.io/rb/karafka)
[![Join the chat at https://slack.karafka.io](https://raw.githubusercontent.com/karafka/misc/master/slack.svg)](https://slack.karafka.io)

**Note**: All of the documentation here refers to Karafka `2.0`. If you are looking for the documentation to Karafka `1.4` please click here (TBA).

## About Karafka

Karafka is a framework used to simplify Apache Kafka based Ruby and Ruby on Rails applications development.

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

Karafka allows you to capture everything that happens in your systems in large scale, providing you with a seamless and stable core for consuming, processing and producing data, without having to focus on things that are not your business domain.

Karafka uses threads to handle many messages at the same time in the same process. It does not require Rails but will integrate tightly with Rails to make event processing dead simple.

- You can integrate Karafka with **any** Ruby-based application.
- Karafka **is** multi-threaded.
- Karafka works with Ruby on Rails but it is a **standalone** framework that can work without it.
- Karafka has a **minimal** set of dependencies, so adding it won't be a huge burden for your already existing applications.
- Karafka processes can be executed for a **given subset** of consumer groups and/or topics, so you can fine tune it depending on your business logic.

## Getting started

If you're completely new to the subject, you can start with our "Kafka on Rails" articles series, that will get you up and running with the terminology and basic ideas behind using Kafka:

- [Kafka on Rails: Using Kafka with Ruby on Rails – Part 1 – Kafka basics and its advantages](https://mensfeld.pl/2017/11/kafka-on-rails-using-kafka-with-ruby-on-rails-part-1-kafka-basics-and-its-advantages/)
- [Kafka on Rails: Using Kafka with Ruby on Rails – Part 2 – Getting started with Ruby and Kafka](https://mensfeld.pl/2018/01/kafka-on-rails-using-kafka-with-ruby-on-rails-part-2-getting-started-with-ruby-and-kafka/)

If you want to get started with Kafka and Karafka as fast as possible, then the best idea is to visit our [Getting started](https://github.com/karafka/karafka/wiki/Getting-started) guides and the [example apps repository](https://github.com/karafka/example-apps).

We also maintain many [integration specs](https://github.com/karafka/karafka/tree/master/spec/integrations) illustrating various use-cases and features of the framework.

## Support

Karafka has [Wiki pages](https://github.com/karafka/karafka/wiki) for almost everything and a pretty decent [FAQ](https://github.com/karafka/karafka/wiki/FAQ). It covers the whole installation, setup, and deployment along with other useful details on how to run Karafka.

If you have any questions about using Karafka, feel free to join our [Slack](https://slack.karafka.io) channel.

## Note on contributions

First, thank you for considering contributing to the Karafka ecosystem! It's people like you that make the open source community such a great community!

Each pull request must pass all the RSpec specs, integration tests and meet our quality requirements.

Fork it, update and wait for the Github Actions results.
