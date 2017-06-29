![karafka logo](http://mensfeld.github.io/karafka-framework-introduction/img/karafka-04.png)

Framework used to simplify Apache Kafka based Ruby applications development.

It allows programmers to use approach similar to "the Rails way" when working with asynchronous Kafka messages.

Karafka not only handles incoming messages but also provides tools for building complex data-flow applications that receive and send messages.

## How does it work

Karafka provides a higher-level abstraction than raw Kafka Ruby drivers, such as Kafka-Ruby and Poseidon. Instead of focusing on  single topic consumption, it provides developers with a set of tools that are dedicated for building multi-topic applications similarly to how Rails applications are being built.

## Support

Karafka has a [Wiki pages](https://github.com/karafka/karafka/wiki) for almost everything. It covers the whole installation, setup and deployment along with other useful details on how to run Karafka.

If you have any questions about using Karafka, feel free to join our [Gitter](https://gitter.im/karafka/karafka) chat channel.

## Requirements

In order to use Karafka framework, you need to have:

  - Zookeeper (required by Kafka)
  - Kafka (at least 0.9.0)
  - Ruby (at least 2.3.0)
