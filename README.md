![karafka logo](http://mensfeld.github.io/karafka-framework-introduction/img/karafka-04.png)

[![Build Status](https://travis-ci.org/karafka/karafka.png)](https://travis-ci.org/karafka/karafka)
[![Code Climate](https://codeclimate.com/github/karafka/karafka/badges/gpa.svg)](https://codeclimate.com/github/karafka/karafka)
[![Join the chat at https://gitter.im/karafka/karafka](https://badges.gitter.im/karafka/karafka.svg)](https://gitter.im/karafka/karafka?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Framework used to simplify Apache Kafka based Ruby applications development.

It allows programmers to use approach similar to "the Rails way" when working with asynchronous Kafka messages.

Karafka not only handles incoming messages but also provides tools for building complex data-flow applications that receive and send messages.

## How does it work

Karafka provides a higher-level abstraction than raw Kafka Ruby drivers, such as Kafka-Ruby and Poseidon. Instead of focusing on  single topic consumption, it provides developers with a set of tools that are dedicated for building multi-topic applications similarly to how Rails applications are being built.

## Support

Karafka has a [Wiki pages](https://github.com/karafka/karafka/wiki) for almost everything. It covers the whole installation, setup and deployment along with other useful details on how to run Karafka.

If you have any questions about using Karafka, feel free to join our [Gitter](https://gitter.im/karafka/karafka) chat channel.

Karafka dev team also provides commercial support in following matters:

- Additional programming services for integrating existing Ruby apps with Kafka and Karafka
- Expertise and guidance on using Karafka within new and existing projects
- Trainings on how to design and develop systems based on Apache Kafka and Karafka framework

If you are interested in our commercial services, please contact [Maciej Mensfeld (maciej@coditsu.io)](mailto:maciej@coditsu.io) directly.

## Warning

Karafka framework and Karafka team is __not__ related to Kafka streaming service called CloudKarafka in any matter. We don't recommend nor discourage usage of their platform.

## Requirements

In order to use Karafka framework, you need to have:

  - Zookeeper (required by Kafka)
  - Kafka (at least 0.9.0)
  - Ruby (at least 2.3.0)

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
