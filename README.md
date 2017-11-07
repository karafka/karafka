![karafka logo](https://raw.githubusercontent.com/karafka/misc/master/logo/karafka_logotype_transparent2.png)

[![Build Status](https://travis-ci.org/karafka/karafka.svg?branch=master)](https://travis-ci.org/karafka/karafka)

Framework used to simplify Apache Kafka based Ruby applications development.

It allows programmers to use approach similar to standard HTTP conventions (```params``` and ```params_batch```) when working with asynchronous Kafka messages.

Karafka not only handles incoming messages but also provides tools for building complex data-flow applications that receive and send messages.

## How does it work

Karafka provides a higher-level abstraction that allows you to focus on your business logic development, instead of focusing on implementing lower level abstraction layers. It provides developers with a set of tools that are dedicated for building multi-topic applications similarly to how Rails applications are being built.

### Some things you might wonder about:

- You can integrate Karafka with any Ruby based application.
- Karafka does **not** require Sidekiq or any other third party software (apart from Kafka itself).
- Karafka works with Ruby on Rails but it is a standalone framework that can work without it.
- Karafka has a minimal set of dependencies, so adding it won't be a huge burden for your already existing applications.

Karafka based applications can be easily deployed to any type of infrastructure, including those based on:

* Heroku
* Capistrano
* Docker

## Support

Karafka has a [Wiki pages](https://github.com/karafka/karafka/wiki) for almost everything and a pretty decent [FAQ](https://github.com/karafka/karafka/wiki/FAQ). It covers the whole installation, setup and deployment along with other useful details on how to run Karafka.

If you have any questions about using Karafka, feel free to join our [Gitter](https://gitter.im/karafka/karafka) chat channel.

## Getting started

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

## Note on Patches/Pull Requests

Fork the project.
Make your feature addition or bug fix.
Add tests for it. This is important so we don't break it in a future versions unintentionally.
Commit, do not mess with Rakefile, version, or history. (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull). Send me a pull request. Bonus points for topic branches.

[![coditsu](https://coditsu.io/assets/quality_bar.svg)](https://app.coditsu.io/karafka/repositories/karafka)

Each pull request must pass our quality requirements. To check if everything is as it should be, we use [Coditsu](https://coditsu.io) that combines multiple linters and code analyzers for both code and documentation.

Unfortunately, it does not yet support independent forks, however you should be fine by looking at what we require.

Please run:

```bash
bundle exec rspec
```

to check if everything is in order. After that you can submit a pull request.

## Contributors

This project exists thanks to all the people who contribute.
<a href="https://github.com/karafka/karafka/graphs/contributors"><img src="https://opencollective.com/karafka/contributors.svg?width=890" /></a>

## Sponsors

We are looking for sustainable sponsorship. If your company is relying on Karafka framework or simply want to see Karafka evolve faster to meet your requirements, please consider backing the project.

Please contact [Maciej Mensfeld](mailto:maciej@coditsu.io) directly for more details.
