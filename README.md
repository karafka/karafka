![karafka logo](http://mensfeld.github.io/karafka-framework-introduction/img/karafka-04.png)

[![Build Status](https://travis-ci.org/karafka/karafka.png)](https://travis-ci.org/karafka/karafka)
[![Backers on Open Collective](https://opencollective.com/karafka/backers/badge.svg)](#backers) [![Sponsors on Open Collective](https://opencollective.com/karafka/sponsors/badge.svg)](#sponsors) [![Join the chat at https://gitter.im/karafka/karafka](https://badges.gitter.im/karafka/karafka.svg)](https://gitter.im/karafka/karafka?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Framework used to simplify Apache Kafka based Ruby applications development.

It allows programmers to use approach similar to standard HTTP conventions (```params``` and ```params_batch```) when working with asynchronous Kafka messages.

Karafka not only handles incoming messages but also provides tools for building complex data-flow applications that receive and send messages.

## How does it work

Karafka provides a higher-level abstraction that allows you to focus on your business logic development, instead of focusing on  implementing lower level abstration layers. It provides developers with a set of tools that are dedicated for building multi-topic applications similarly to how Rails applications are being built.

Karafka based applications can be easily deployed to any type of infrastructure, including those based on:

* Heroku
* Capistrano
* Docker

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

**Note**: you need to ensure, that you have Kafka up and running and you need to configure Kafka seed_brokers in the ```app.rb``` file.

If you need more details and know how to start karafka with a clean installation read [Getting started page](https://github.com/karafka/karafka/wiki/Getting-started) in Wiki.

## Support

Karafka has a [Wiki pages](https://github.com/karafka/karafka/wiki) for almost everything. It covers the whole installation, setup and deployment along with other useful details on how to run Karafka.

If you have any questions about using Karafka, feel free to join our [Gitter](https://gitter.im/karafka/karafka) chat channel.

Karafka dev team also provides commercial support in following matters:

- Additional programming services for integrating existing Ruby apps with Kafka and Karafka
- Expertise and guidance on using Karafka within new and existing projects
- Trainings on how to design and develop systems based on Apache Kafka and Karafka framework

If you are interested in our commercial services, please contact [Maciej Mensfeld (maciej@coditsu.io)](mailto:maciej@coditsu.io) directly.

## Notice

Karafka framework and Karafka team are __not__ related to Kafka streaming service called CloudKarafka in any matter. We don't recommend nor discourage usage of their platform.

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

## Contributors

This project exists thanks to all the people who contribute. [[Contribute]](CONTRIBUTING.md).
<a href="https://github.com/karafka/karafka/graphs/contributors"><img src="https://opencollective.com/karafka/contributors.svg?width=890" /></a>


## Backers

Thank you to all our backers! 🙏 [[Become a backer](https://opencollective.com/karafka#backer)]

<a href="https://opencollective.com/karafka#backers" target="_blank"><img src="https://opencollective.com/karafka/backers.svg?width=890"></a>


## Sponsors

We are looking for sustainable sponsorship. If your company is relying on Karafka framework or simply want to see Karafka evolve faster to meet your requirements, please consider backing the project. [[Become a sponsor](https://opencollective.com/karafka#sponsor)]

Please contact [Maciej Mensfeld (maciej@coditsu.io)](mailto:maciej@coditsu.io) directly for more details.


<a href="https://opencollective.com/karafka/sponsor/0/website" target="_blank"><img src="https://opencollective.com/karafka/sponsor/0/avatar.svg"></a>
<a href="https://opencollective.com/karafka/sponsor/1/website" target="_blank"><img src="https://opencollective.com/karafka/sponsor/1/avatar.svg"></a>
<a href="https://opencollective.com/karafka/sponsor/2/website" target="_blank"><img src="https://opencollective.com/karafka/sponsor/2/avatar.svg"></a>
<a href="https://opencollective.com/karafka/sponsor/3/website" target="_blank"><img src="https://opencollective.com/karafka/sponsor/3/avatar.svg"></a>
<a href="https://opencollective.com/karafka/sponsor/4/website" target="_blank"><img src="https://opencollective.com/karafka/sponsor/4/avatar.svg"></a>
<a href="https://opencollective.com/karafka/sponsor/5/website" target="_blank"><img src="https://opencollective.com/karafka/sponsor/5/avatar.svg"></a>
<a href="https://opencollective.com/karafka/sponsor/6/website" target="_blank"><img src="https://opencollective.com/karafka/sponsor/6/avatar.svg"></a>
<a href="https://opencollective.com/karafka/sponsor/7/website" target="_blank"><img src="https://opencollective.com/karafka/sponsor/7/avatar.svg"></a>
<a href="https://opencollective.com/karafka/sponsor/8/website" target="_blank"><img src="https://opencollective.com/karafka/sponsor/8/avatar.svg"></a>
<a href="https://opencollective.com/karafka/sponsor/9/website" target="_blank"><img src="https://opencollective.com/karafka/sponsor/9/avatar.svg"></a>


