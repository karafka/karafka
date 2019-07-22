---
name: Bug Report
about: Report an issue with Karafka you've discovered.
---

*Be clear, concise and precise in your description of the problem.
Open an issue with a descriptive title and a summary in grammatically correct,
complete sentences.*

*Use the template below when reporting bugs. Please, make sure that
you're running the latest stable Karafka and that the problem you're reporting
hasn't been reported (and potentially fixed) already.*

*Before filing the ticket you should replace all text above the horizontal
rule with your own words.*

--------

## Expected behavior

Describe here how you expected Karafka to behave in this particular situation.

## Actual behavior

Describe here what actually happened.

## Steps to reproduce the problem

This is extremely important! Providing us with a reliable way to reproduce
a problem will expedite its solution.

## Your setup details

Please provide kafka version and the output of `karafka info` or `bundle exec karafka info` if using Bundler.

Here's an example:

```
$ [bundle exec] karafka info
Karafka version: 1.3.0
Ruby version: 2.6.3
Ruby-kafka version: 0.7.9
Application client id: karafka-local
Backend: inline
Batch fetching: true
Batch consuming: true
Boot file: /app/karafka/karafka.rb
Environment: development
Kafka seed brokers: ["kafka://kafka:9092"]
```
