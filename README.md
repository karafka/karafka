![karafka logo](https://raw.githubusercontent.com/karafka/misc/master/logo/karafka_logotype_transparent2.png)

[![Build Status](https://travis-ci.org/karafka/karafka.svg?branch=master)](https://travis-ci.org/karafka/karafka)

Framework used to simplify Apache Kafka based Ruby applications development.

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

## Kafka 0.10 or prior

If you're using Kafka 0.10, please lock `ruby-kafka` gem in your Gemfile to version `0.6.8`:

```ruby
gem 'karafka'
gem 'ruby-kafka', '~> 0.6.8'
```

## Support

Karafka has a [Wiki pages](https://github.com/karafka/karafka/wiki) for almost everything and a pretty decent [FAQ](https://github.com/karafka/karafka/wiki/FAQ). It covers the whole installation, setup, and deployment along with other useful details on how to run Karafka.

If you have any questions about using Karafka, feel free to join our [Gitter](https://gitter.im/karafka/karafka) chat channel.

## Getting started

If you're completely new to the subject, you can start with our "Kafka on Rails" articles series, that will get you up and running with the terminology and basic ideas behind using Kafka:

- [Kafka on Rails: Using Kafka with Ruby on Rails – Part 1 – Kafka basics and its advantages](https://mensfeld.pl/2017/11/kafka-on-rails-using-kafka-with-ruby-on-rails-part-1-kafka-basics-and-its-advantages/)
- [Kafka on Rails: Using Kafka with Ruby on Rails – Part 2 – Getting started with Ruby and Kafka](https://mensfeld.pl/2018/01/kafka-on-rails-using-kafka-with-ruby-on-rails-part-2-getting-started-with-ruby-and-kafka/)

If you want to get started with Kafka and Karafka as fast as possible, then the best idea is to just clone our example repository:

```bash
git clone https://github.com/karafka/karafka-example-app ./example_app
```

then, just bundle install all the dependencies:

```bash
cd ./example_app
bundle install
```

and follow the instructions from the [example app Wiki](https://github.com/karafka/karafka-example-app/blob/master/README.md).

**Note**: you need to ensure, that you have Kafka up and running and you need to configure Kafka seed_brokers in the ```karafka.rb``` file.

If you need more details and know how on how to start Karafka with a clean installation, read the [Getting started page](https://github.com/karafka/karafka/wiki/Getting-started) section of our Wiki.

## Notice

Karafka framework and Karafka team are __not__ related to Kafka streaming service called CloudKarafka in any matter. We don't recommend nor discourage usage of their platform.

## References

* [Karafka framework](https://github.com/karafka/karafka)
* [Karafka Travis CI](https://travis-ci.org/karafka/karafka)
* [Karafka Coditsu](https://app.coditsu.io/karafka/repositories/karafka)

## Note on contributions

First, thank you for considering contributing to Karafka! It's people like you that make the open source community such a great community!

Each pull request must pass all the RSpec specs and meet our quality requirements.

To check if everything is as it should be, we use [Coditsu](https://coditsu.io) that combines multiple linters and code analyzers for both code and documentation. Once you're done with your changes, submit a pull request.

Coditsu will automatically check your work against our quality standards. You can find your commit check results on the [builds page](https://app.coditsu.io/karafka/commit_builds) of Karafka organization.

[![coditsu](https://coditsu.io/assets/quality_bar.svg)](https://app.coditsu.io/karafka/commit_builds)

## Contributors

This project exists thanks to all the people who contribute.
<a href="https://github.com/karafka/karafka/graphs/contributors"><img src="https://opencollective.com/karafka/contributors.svg?width=890" /></a>

## Sponsors

We are looking for sustainable sponsorship. If your company is relying on Karafka framework or simply want to see Karafka evolve faster to meet your requirements, please consider backing the project.

Please contact [Maciej Mensfeld](mailto:maciej@coditsu.io) directly for more details.
