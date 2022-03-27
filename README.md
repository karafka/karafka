![karafka logo](https://raw.githubusercontent.com/karafka/misc/master/logo/karafka_logotype_transparent2.png)

[![Build Status](https://github.com/karafka/karafka/actions/workflows/ci.yml/badge.svg)](https://github.com/karafka/karafka/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/karafka.svg)](http://badge.fury.io/rb/karafka)
[![Join the chat at https://slack.karafka.io](https://raw.githubusercontent.com/karafka/misc/master/slack.svg)](https://slack.karafka.io)

**Note**: We're finishing the new Karafka `2.0` but for now, please use `1.4`. All the documentation presented here refers to `1.4`

## About Karafka

Framework used to simplify Apache Kafka based Ruby applications development.

```ruby
# Define what topics you want to consume with which consumers
Karafka::App.consumer_groups.draw do
  topic 'system_events' do
    consumer EventsConsumer
  end
end

# And create your consumers, within which your messages will be processed
class EventsConsumer < ApplicationConsumer
  # Example that utilizes ActiveRecord#insert_all and Karafka batch processing
  def consume
    # Store all of the incoming Kafka events locally in an efficient way
    Event.insert_all params_batch.payloads
  end
end
```

Karafka allows you to capture everything that happens in your systems in large scale, providing you with a seamless and stable core for consuming and processing this data, without having to focus on things that are not your business domain.

Karafka not only handles incoming messages but also provides tools for building complex data-flow applications that receive and send messages.

## How does it work

Karafka provides a higher-level abstraction that allows you to focus on your business logic development, instead of focusing on implementing lower level abstraction layers. It provides developers with a set of tools that are dedicated for building multi-topic applications similar to how Rails applications are being built.

### Some things you might wonder about:

- You can integrate Karafka with **any** Ruby-based application.
- Karafka does **not** require Sidekiq or any other third party software (apart from Kafka itself).
- Karafka works with Ruby on Rails but it is a **standalone** framework that can work without it.
- Karafka has a **minimal** set of dependencies, so adding it won't be a huge burden for your already existing applications.
- Karafka processes can be executed for a **given subset** of consumer groups and/or topics, so you can fine tune it depending on your business logic.

Karafka based applications can be easily deployed to any type of infrastructure, including those based on:

* Heroku
* Capistrano
* Docker
* Terraform

## Support

Karafka has [Wiki pages](https://github.com/karafka/karafka/wiki) for almost everything and a pretty decent [FAQ](https://github.com/karafka/karafka/wiki/FAQ). It covers the whole installation, setup, and deployment along with other useful details on how to run Karafka.

If you have any questions about using Karafka, feel free to join our [Slack](https://slack.karafka.io) chat channel.

## Getting started

If you're completely new to the subject, you can start with our "Kafka on Rails" articles series, that will get you up and running with the terminology and basic ideas behind using Kafka:

- [Kafka on Rails: Using Kafka with Ruby on Rails – Part 1 – Kafka basics and its advantages](https://mensfeld.pl/2017/11/kafka-on-rails-using-kafka-with-ruby-on-rails-part-1-kafka-basics-and-its-advantages/)
- [Kafka on Rails: Using Kafka with Ruby on Rails – Part 2 – Getting started with Ruby and Kafka](https://mensfeld.pl/2018/01/kafka-on-rails-using-kafka-with-ruby-on-rails-part-2-getting-started-with-ruby-and-kafka/)

If you want to get started with Kafka and Karafka as fast as possible, then the best idea is to just clone our example repository:

```bash
git clone https://github.com/karafka/example-app ./example_app
```

then, just bundle install all the dependencies:

```bash
cd ./example_app
bundle install
```

and follow the instructions from the [example app Wiki](https://github.com/karafka/example-app/blob/master/README.md).

**Note**: you need to ensure, that you have Kafka up and running and you need to configure Kafka seed_brokers in the ```karafka.rb``` file.

If you need more details and know how on how to start Karafka with a clean installation, read the [Getting started page](https://github.com/karafka/karafka/wiki/Getting-started) section of our Wiki.

## References

* [Karafka framework](https://github.com/karafka/karafka)
* [Karafka GitHub Actions](https://github.com/karafka/karafka/actions)
* [Karafka Coditsu](https://app.coditsu.io/karafka/repositories/karafka)

## Note on contributions

First, thank you for considering contributing to the Karafka ecosystem! It's people like you that make the open source community such a great community!

Each pull request must pass all the RSpec specs, integration tests and meet our quality requirements.

Fork it, update and wait for the Github Actions results.
