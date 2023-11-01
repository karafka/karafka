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
Karafka version: 2.2.10 + Pro
Ruby version: ruby 3.2.2 (2023-03-30 revision e51014f9c0) [x86_64-linux]
Rdkafka version: 0.13.8
Consumer groups count: 2
Subscription groups count: 2
Workers count: 2
Application client id: example_app
Boot file: /app/karafka.rb
Environment: development
License: Commercial
License entity: karafka-ci
```
