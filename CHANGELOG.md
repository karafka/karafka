# Karafka framework changelog

## Unreleased
- [Improvement] Load Pro components upon Karafka require so they can be altered prior to setup.
- [Improvement] Do not run LRJ jobs that were added to the jobs queue but were revoked meanwhile.
- [Improvement] Allow running particular named subscription groups similar to consumer groups.
- [Improvement] Allow running particular topics similar to consumer groups.
- [Improvement] Raise configuration error when trying to run Karafka with options leading to no subscriptions.
- [Fix] Fix `karafka info` subscription groups count reporting as it was misleading.
- [Fix] Allow for defining subscription groups with symbols similar to consumer groups and topics to align the API.
- [Fix] Do not allow for an explicit `nil` as a `subscription_group` block argument.
- [Fix] Fix instability in subscription groups static members ids when using `--consumer_groups` CLI flag.
- [Fix] Fix a case in routing, where anonymous subscription group could not be used inside of a consumer group.
- [Fix] Fix a case where shutdown prior to listeners build would crash the server initialization.
- [Fix] Duplicated logs in development environment for Rails when logger set to `$stdout`.

## 20.0.21 (2022-11-25)
- [Improvement] Make revocation jobs for LRJ topics non-blocking to prevent blocking polling when someone uses non-revocation aware LRJ jobs and revocation happens.

## 2.0.20 (2022-11-24)
- [Improvement] Support `group.instance.id` assignment (static group membership) for a case where a single consumer group has multiple subscription groups (#1173).

## 2.0.19 (2022-11-20)
- **[Feature]** Provide ability to skip failing messages without dispatching them to an alternative topic (DLQ).
- [Improvement] Improve the integration with Ruby on Rails by preventing double-require of components.
- [Improvement] Improve stability of the shutdown process upon critical errors.
- [Improvement] Improve stability of the integrations spec suite.
- [Fix] Fix an issue where upon fast startup of multiple subscription groups from the same consumer group, a ghost queue would be created due to problems in `Concurrent::Hash`.

## 2.0.18 (2022-11-18)
- **[Feature]** Support quiet mode via `TSTP` signal. When used, Karafka will finish processing current messages, run `shutdown` jobs, and switch to a quiet mode where no new work is being accepted. At the same time, it will keep the consumer group quiet, and thus no rebalance will be triggered. This can be particularly useful during deployments.
- [Improvement] Trigger `#revoked` for jobs in case revocation would happen during shutdown when jobs are still running. This should ensure, we get a notion of revocation for Pro LRJ jobs even when revocation happening upon shutdown (#1150).
- [Improvement] Stabilize the shutdown procedure for consumer groups with many subscription groups that have non-aligned processing cost per batch.
- [Improvement] Remove double loading of Karafka via Rails railtie.
- [Fix] Fix invalid class references in YARD docs.
- [Fix] prevent parallel closing of many clients.
- [Fix] fix a case where information about revocation for a combination of LRJ + VP would not be dispatched until all VP work is done.

## 2.0.17 (2022-11-10)
- [Fix] Few typos around DLQ and Pro DLQ Dispatch original metadata naming.
- [Fix] Narrow the components lookup to the appropriate scope (#1114)

### Upgrade notes

1. Replace `original-*` references from DLQ dispatched metadata with `original_*`

```ruby
# DLQ topic consumption
def consume
  messages.each do |broken_message|
    topic = broken_message.metadata['original_topic'] # was original-topic
    partition = broken_message.metadata['original_partition'] # was original-partition
    offset = broken_message.metadata['original_offset'] # was original-offset

    Rails.logger.error "This message is broken: #{topic}/#{partition}/#{offset}"
  end
end
```

## 2.0.16 (2022-11-09)
- **[Breaking]** Disable the root `manual_offset_management` setting and require it to be configured per topic. This is part of "topic features" configuration extraction for better code organization.
- **[Feature]** Introduce **Dead Letter Queue** feature and Pro **Enhanced Dead Letter Queue** feature
- [Improvement] Align attributes available in the instrumentation bus for listener related events.
- [Improvement] Include consumer group id in consumption related events (#1093)
- [Improvement] Delegate pro components loading to Zeitwerk
- [Improvement] Include `Datadog::LoggerListener` for tracking logger data with DataDog (@bruno-b-martins)
- [Improvement] Include `seek_offset` in the `consumer.consume.error` event payload (#1113)
- [Refactor] Remove unused logger listener event handler.
- [Refactor] Internal refactoring of routing validations flow.
- [Refactor] Reorganize how routing related features are represented internally to simplify features management.
- [Refactor] Extract supported features combinations processing flow into separate strategies.
- [Refactor] Auto-create topics in the integration specs based on the defined routing
- [Refactor] Auto-inject Pro components via composition instead of requiring to use `Karafka::Pro::BaseConsumer` (#1116)
- [Fix] Fix a case where routing tags would not be injected when given routing definition would not be used with a block
- [Fix] Fix a case where using `#active_job_topic` without extra block options would cause `manual_offset_management` to stay false.
- [Fix] Fix a case when upon Pro ActiveJob usage with Virtual Partitions, correct offset would not be stored
- [Fix] Fix a case where upon Virtual Partitions usage, same underlying real partition would be resumed several times.
- [Fix] Fix LRJ enqueuing pause increases the coordinator counter (#115)
- [Fix] Release `ActiveRecord` connection to the pool after the work in non-dev envs (#1130)
- [Fix] Fix a case where post-initialization shutdown would not initiate shutdown procedures.
- [Fix] Prevent Karafka from committing offsets twice upon shutdown.
- [Fix] Fix for a case where fast consecutive stop signaling could hang the stopping listeners.
- [Specs] Split specs into regular and pro to simplify how resources are loaded
- [Specs] Add specs to ensure, that all the Pro components have a proper per-file license (#1099)

### Upgrade notes

1. Remove the `manual_offset_management` setting from the main config if you use it:

```ruby
class KarafkaApp < Karafka::App
  setup do |config|
    # ...

    # This line needs to be removed:
    config.manual_offset_management = true
  end
end
```

2. Set the `manual_offset_management` feature flag per each topic where you want to use it in the routing. Don't set it for topics where you want the default offset management strategy to be used.

```ruby
class KarafkaApp < Karafka::App
  routes.draw do
    consumer_group :group_name do
      topic :example do
        consumer ExampleConsumer
        manual_offset_management true
      end

      topic :example2 do
        consumer ExampleConsumer2
        manual_offset_management true
      end
    end
  end
end
```

3. If you were using code to restart dead connections similar to this:

```ruby
class ActiveRecordConnectionsCleaner
  def on_error_occurred(event)
    return unless event[:error].is_a?(ActiveRecord::StatementInvalid)

    ::ActiveRecord::Base.clear_active_connections!
  end
end

Karafka.monitor.subscribe(ActiveRecordConnectionsCleaner.new)
```

It **should** be removed. This code is **no longer needed**.

## 2.0.15 (2022-10-20)
- Sanitize admin config prior to any admin action.
- Make messages partitioner outcome for virtual partitions consistently distributed in regards to concurrency.
- Improve DataDog/StatsD metrics reporting by reporting per topic partition lags and trends.
- Replace synchronous offset commit with async on resuming paused partition (#1087).

## 2.0.14 (2022-10-16)
- Prevent consecutive stop signals from starting multiple supervision shutdowns.
- Provide `Karafka::Embedded` to simplify the start/stop process when running Karafka from within other process (Puma, Sidekiq, etc).
- Fix a race condition when un-pausing a long-running-job exactly upon listener resuming would crash the listener loop (#1072).

## 2.0.13 (2022-10-14)
- Early exit upon attempts to commit current or earlier offset twice.
- Add more integration specs covering edge cases.
- Strip non producer related config when default producer is initialized (#776)

## 2.0.12 (2022-10-06)
- Commit stored offsets upon rebalance revocation event to reduce number of messages that are re-processed.
- Support cooperative-sticky rebalance strategy.
- Replace offset commit after each batch with a per-rebalance commit.
- User instrumentation to publish internal rebalance errors.

## 2.0.11 (2022-09-29)
- Report early on errors related to network and on max poll interval being exceeded to indicate critical problems that will be retries but may mean some underlying problems in the system.
- Fix support of Ruby 2.7.0 to 2.7.2 (#1045)

## 2.0.10 (2022-09-23)
- Improve error recovery by delegating the recovery to the existing `librdkafka` instance.

## 2.0.9 (2022-09-22)
- Fix Singleton not visible when used in PORO (#1034)
- Divide pristine specs into pristine and poro. Pristine will still have helpers loaded, poro will have nothing.
- Fix a case where `manual_offset_management` offset upon error is not reverted to the first message in a case where there were no markings as consumed at all for multiple batches.
- Implement small reliability improvements around marking as consumed.
- Introduce a config sanity check to make sure Virtual Partitions are not used with manual offset management.
- Fix a possibility of using `active_job_topic` with Virtual Partitions and manual offset management (ActiveJob still can use due to atomicity of jobs).
- Move seek offset ownership to the coordinator to allow Virtual Partitions further development.
- Improve client shutdown in specs.
- Do not reset client on network issue and rely on `librdkafka` to do so.
- Allow for nameless (anonymous) subscription groups (#1033)

## 2.0.8 (2022-09-19)
- [Breaking change] Rename Virtual Partitions `concurrency` to `max_partitions` to avoid confusion  (#1023).
-  Allow for block based subscription groups management (#1030).

## 2.0.7 (2022-09-05)
- [Breaking change] Redefine the Virtual Partitions routing DSL to accept concurrency
- Allow for `concurrency` setting in Virtual Partitions to extend or limit number of jobs per regular partition. This allows to make sure, we do not use all the threads on virtual partitions jobs
- Allow for creation of as many Virtual Partitions as needed, without taking global `concurrency` into consideration

## 2.0.6 (2022-09-02)
- Improve client closing.
- Fix for: Multiple LRJ topics fetched concurrently block ability for LRJ to kick in (#1002)
- Introduce a pre-enqueue sync execution layer to prevent starvation cases for LRJ
- Close admin upon critical errors to prevent segmentation faults
- Add support for manual subscription group management (#852)

## 2.0.5 (2022-08-23)
- Fix unnecessary double new line in the `karafka.rb` template for Ruby on Rails
- Fix a case where a manually paused partition would not be processed after rebalance (#988)
- Increase specs stability.
- Lower concurrency of execution of specs in Github CI.

## 2.0.4 (2022-08-19)
- Fix hanging topic creation (#964)
- Fix conflict with other Rails loading libraries like `gruf` (#974)

## 2.0.3 (2022-08-09)
- Update boot info on server startup.
- Update `karafka info` with more descriptive Ruby version info.
- Fix issue where when used with Rails in development, log would be too verbose.
- Fix issue where Zeitwerk with Rails would not load Pro components despite license being present.

## 2.0.2 (2022-08-07)
- Bypass issue with Rails reload in development by releasing the connection (https://github.com/rails/rails/issues/44183).

## 2.0.1 (2022-08-06)
- Provide `Karafka::Admin` for creation and destruction of topics and fetching cluster info.
- Update integration specs to always use one-time disposable topics.
- Remove no longer needed `wait_for_kafka` script.
- Add more integration specs for cover offset management upon errors.

## 2.0.0 (2022-08-05)

This changelog describes changes between `1.4` and `2.0`. Please refer to appropriate release notes for changes between particular `rc` releases.

Karafka 2.0 is a **major** rewrite that brings many new things to the table but also removes specific concepts that happened not to be as good as I initially thought when I created them.

Please consider getting a Pro version if you want to **support** my work on the Karafka ecosystem!

For anyone worried that I will start converting regular features into Pro: This will **not** happen. Anything free and fully OSS in Karafka 1.4 will **forever** remain free. Most additions and improvements to the ecosystem are to its free parts. Any feature that is introduced as a free and open one will not become paid.

### Additions

This section describes **new** things and concepts introduced with Karafka 2.0.

Karafka 2.0:

- Introduces multi-threaded support for [concurrent work](https://github.com/karafka/karafka/wiki/Concurrency-and-multithreading) consumption for separate partitions as well as for single partition work via [Virtual Partitions](https://github.com/karafka/karafka/wiki/Pro-Virtual-Partitions).
- Introduces [Active Job adapter](https://github.com/karafka/karafka/wiki/Active-Job) for using Karafka as a jobs backend with Ruby on Rails Active Job.
- Introduces fully automatic integration end-to-end [test suite](https://github.com/karafka/karafka/tree/master/spec/integrations) that checks any case I could imagine.
- Introduces [Virtual Partitions](https://github.com/karafka/karafka/wiki/Pro-Virtual-Partitions) for ability to parallelize work of a single partition.
- Introduces [Long-Running Jobs](https://github.com/karafka/karafka/wiki/Pro-Long-Running-Jobs) to allow for work that would otherwise exceed the `max.poll.interval.ms`.
- Introduces the [Enhanced Scheduler](https://github.com/karafka/karafka/wiki/Pro-Enhanced-Scheduler) that uses a non-preemptive LJF (Longest Job First) algorithm instead of a a FIFO (First-In, First-Out) one.
- Introduces [Enhanced Active Job adapter](https://github.com/karafka/karafka/wiki/Pro-Enhanced-Active-Job) that is optimized and allows for strong ordering of jobs and more.
- Introduces seamless [Ruby on Rails integration](https://github.com/karafka/karafka/wiki/Integrating-with-Ruby-on-Rails-and-other-frameworks) via `Rails::Railte` without need for any extra configuration.
- Provides `#revoked` [method](https://github.com/karafka/karafka/wiki/Consuming-messages#shutdown-and-partition-revocation-handlers) for taking actions upon topic revocation.
- Emits underlying async errors emitted from `librdkafka` via the standardized `error.occurred` [monitor channel](https://github.com/karafka/karafka/wiki/Error-handling-and-back-off-policy#error-tracking).
- Replaces `ruby-kafka` with `librdkafka` as an underlying driver.
- Introduces official [EOL policies](https://github.com/karafka/karafka/wiki/Versions-Lifecycle-and-EOL).
- Introduces [benchmarks](https://github.com/karafka/karafka/tree/master/spec/benchmarks) that can be used to profile Karafka.
- Introduces a requirement that the end user code **needs** to be [thread-safe](https://github.com/karafka/karafka/wiki/FAQ#does-karafka-require-gems-to-be-thread-safe).
- Introduces a [Pro subscription](https://github.com/karafka/karafka/wiki/Build-vs-Buy) with a [commercial license](https://github.com/karafka/karafka/blob/master/LICENSE-COMM) to fund further ecosystem development.

### Deletions

This section describes things that are **no longer** part of the Karafka ecosystem.

Karafka 2.0:

- Removes topics mappers concept completely.
- Removes pidfiles support.
- Removes daemonization support.
- Removes support for using `sidekiq-backend` due to introduction of [multi-threading](https://github.com/karafka/karafka/wiki/Concurrency-and-multithreading).
- Removes the `Responders` concept in favour of WaterDrop producer usage.
- Removes completely all the callbacks in favour of finalizer method `#shutdown`.
- Removes single message consumption mode in favour of [documentation](https://github.com/karafka/karafka/wiki/Consuming-messages#one-at-a-time) on how to do it easily by yourself.

### Changes

This section describes things that were **changed** in Karafka but are still present.

Karafka 2.0:

- Uses only instrumentation that comes from Karafka. This applies also to notifications coming natively from `librdkafka`. They are now piped through Karafka prior to being dispatched.
- Integrates WaterDrop `2.x` tightly with autoconfiguration inheritance and an option to redefine it.
- Integrates with the `karafka-testing` gem for RSpec that also has been updated.
- Updates `cli info` to reflect the `2.0` details.
- Stops validating `kafka` configuration beyond minimum as the rest is handled by `librdkafka`.
- No longer uses `dry-validation`.
- No longer uses `dry-monitor`.
- No longer uses `dry-configurable`.
- Lowers general external dependencies three **heavily**.
- Renames `Karafka::Params::BatchMetadata` to `Karafka::Messages::BatchMetadata`.
- Renames `Karafka::Params::Params` to `Karafka::Messages::Message`.
- Renames `#params_batch` in consumers to `#messages`.
- Renames `Karafka::Params::Metadata` to `Karafka::Messages::Metadata`.
- Renames `Karafka::Fetcher` to `Karafka::Runner` and align notifications key names.
- Renames `StdoutListener` to `LoggerListener`.
- Reorganizes [monitoring and logging](https://github.com/karafka/karafka/wiki/Monitoring-and-logging) to match new concepts.
- Notifies on fatal worker processing errors.
- Contains updated install templates for Rails and no-non Rails.
- Changes how the routing style (`0.5`) behaves. It now builds a single consumer group instead of one per topic.
- Introduces changes that will allow me to build full web-UI in the upcoming `2.1`.
- Contains updated example apps.
- Standardizes error hooks for all error reporting (`error.occurred`).
- Changes license to `LGPL-3.0`.
- Introduces a `karafka-core` dependency that contains common code used across the ecosystem.
- Contains updated [wiki](https://github.com/karafka/karafka/wiki) on everything I could think of.

### What's ahead

Karafka 2.0 is just the beginning.

There are several things in the plan already for 2.1 and beyond, including a web dashboard, at-rest encryption, transactions support, and more.

## 2.0.0.rc6 (2022-08-05)
- Update licenser to use a gem based approach based on `karafka-license`.
- Do not mark intermediate jobs as consumed when Karafka runs Enhanced Active Job with Virtual Partitions.
- Improve development experience by adding fast cluster state changes refresh (#944)
- Improve the license loading.

## 2.0.0.rc5 (2022-08-01)
- Improve specs stability
- Improve forceful shutdown
- Add support for debug `TTIN` backtrace printing
- Fix a case where logger listener would not intercept `warn` level
- Require `rdkafka` >= `0.12`
- Replace statistics decorator with the one from `karafka-core`

## 2.0.0.rc4 (2022-07-28)
- Remove `dry-monitor`
- Use `karafka-core`
- Improve forceful shutdown resources finalization
- Cache consumer client name

## 2.0.0.rc3 (2022-07-26)
- Fix Pro partitioner hash function may not utilize all the threads (#907).
- Improve virtual partitions messages distribution.
- Add StatsD/DataDog optional monitoring listener + dashboard template.
- Validate that Pro consumer is always used for Pro subscription.
- Improve ActiveJob consumer shutdown behaviour.
- Change default `max_wait_time` to 1 second.
- Change default `max_messages` to 100 (#915).
- Move logger listener polling reporting level to debug when no messages (#916).
- Improve stability on aggressive rebalancing (multiple rebalances in a short period).
- Improve specs stability.
- Allow using `:key` and `:partition_key` for Enhanced Active Job partitioning.

## 2.0.0.rc2 (2022-07-19)
- Fix `example_consumer.rb.erb` `#shutdown` and `#revoked` signatures to correct once.
- Improve the install user experience (print status and created files).
- Change default `max_wait_time` from 10s to 5s.
- Remove direct dependency on `dry-configurable` in favour of a home-brew.
- Remove direct dependency on `dry-validation` in favour of a home-brew.

## 2.0.0-rc1 (2022-07-08)
- Extract consumption partitioner out of listener inline code.
- Introduce virtual partitioner concept for parallel processing of data from a single topic partition.
- Improve stability when there kafka internal errors occur while polling.
- Fix a case where we would resume a LRJ partition upon rebalance where we would reclaim the partition while job was still running.
- Do not revoke pauses for lost partitions. This will allow to un-pause reclaimed partitions when LRJ jobs are done.
- Fail integrations by default (unless configured otherwise) if any errors occur during Karafka server execution.

## 2.0.0-beta5 (2022-07-05)
- Always resume processing of a revoked partition upon assignment.
- Improve specs stability.
- Fix a case where revocation job would be executed on partition for which we never did any work.
- Introduce a jobs group coordinator for easier jobs management.
- Improve stability of resuming paused partitions that were revoked and re-assigned.
- Optimize reaction time on partition ownership changes.
- Fix a bug where despite setting long max wait time, we would return messages prior to it while not reaching the desired max messages count.
- Add more integration specs related to polling limits.
- Remove auto-detection of re-assigned partitions upon rebalance as for too fast rebalances it could not be accurate enough. It would also mess up in case of rebalances that would happen right after a `#seek` was issued for a partition.
- Optimize the removal of pre-buffered lost partitions data.
- Always run `#revoked` when rebalance with revocation happens.
- Evict executors upon rebalance, to prevent race-conditions.
- Align topics names for integration specs.

## 2.0.0-beta4 (2022-06-20)
- Rename job internal api methods from `#prepare` to `#before_call` and from `#teardown` to `#after_call` to abstract away jobs execution from any type of executors and consumers logic
- Remove ability of running `before_consume` and `after_consume` completely. Those should be for internal usage only.
- Reorganize how Pro consumer and Pro AJ consumers inherit.
- Require WaterDrop `2.3.1`.
- Add more integration specs for rebalancing and max poll exceeded.
- Move `revoked?` state from PRO to regular Karafka.
- Use return value of `mark_as_consumed!` and `mark_as_consumed` as indicator of partition ownership + use it to switch the ownership state.
- Do not remove rebalance manager upon client reset and recovery. This will allow us to keep the notion of lost partitions, so we can run revocation jobs for blocking jobs that exceeded the max poll interval.
- Run revocation jobs upon reaching max poll interval for blocking jobs.
- Early exit `poll` operation upon partition lost or max poll exceeded event.
- Always reset consumer instances on timeout exceeded.
- Wait for Kafka to create all the needed topics before running specs in CI.

## 2.0.0-beta3 (2022-06-14)
- Jobs building responsibility extracted out of the listener code base.
- Fix a case where specs supervisor would try to kill no longer running process (#868)
- Fix an instable integration spec that could misbehave under load
- Commit offsets prior to pausing partitions to ensure that the latest offset is always committed
- Fix a case where consecutive CTRL+C (non-stop) would case an exception during forced shutdown
- Add missing `consumer.prepared.error` into `LoggerListener`
- Delegate partition resuming from the consumers to listeners threads.
- Add support for Long-Running Jobs (LRJ) for ActiveJob [PRO]
- Add support for Long-Running Jobs for consumers [PRO]
- Allow `active_job_topic` to accept a block for extra topic related settings
- Remove no longer needed logger threads
- Auto-adapt number of processes for integration specs based on the number of CPUs
- Introduce an integration spec runner that prints everything to stdout (better for development)
- Introduce extra integration specs for various ActiveJob usage scenarios
- Rename consumer method `#prepared` to `#prepare` to reflect better its use-case
- For test and dev raise an error when expired license key is used (never for non dev)
- Add worker related monitor events (`worker.process` and `worker.processed`)
- Update `LoggerListener` to include more useful information about processing and polling messages

## 2.0.0-beta2 (2022-06-07)
- Abstract away notion of topics groups (until now it was just an array)
- Optimize how jobs queue is closed. Since we enqueue jobs only from the listeners, we can safely close jobs queue once listeners are done. By extracting this responsibility from listeners, we remove corner cases and race conditions. Note here: for non-blocking jobs we do wait for them to finish while running the `poll`. This ensures, that for async jobs that are long-living, we do not reach `max.poll.interval`.
- `Shutdown` jobs are executed in workers to align all the jobs behaviours.
- `Shutdown` jobs are always blocking.
- Notion of `ListenersBatch` was introduced similar to `WorkersBatch` to abstract this concept.
- Change default `shutdown_timeout` to be more than `max_wait_time` not to cause forced shutdown when no messages are being received from Kafka.
- Abstract away scheduling of revocation and shutdown jobs for both default and pro schedulers
- Introduce a second (internal) messages buffer to distinguish between raw messages buffer and karafka messages buffer
- Move messages and their metadata remap process to the listener thread to allow for their inline usage
- Change how we wait in the shutdown phase, so shutdown jobs can still use Kafka connection even if they run for a longer period of time. This will prevent us from being kicked out from the group early.
- Introduce validation that ensures, that `shutdown_timeout` is more than `max_wait_time`. This will prevent users from ending up with a config that could lead to frequent forceful shutdowns.

## 2.0.0-beta1 (2022-05-22)
- Update the jobs queue blocking engine and allow for non-blocking jobs execution
- Provide `#prepared` hook that always runs before the fetching loop is unblocked
- [Pro] Introduce performance tracker for scheduling optimizer
- Provide ability to pause (`#pause`) and resume (`#resume`) given partitions from the consumers
- Small integration specs refactoring + specs for pausing scenarios

## 2.0.0-alpha6 (2022-04-17)
- Fix a bug, where upon missing boot file and Rails, railtie would fail with a generic exception (#818) 
- Fix an issue with parallel pristine specs colliding with each other during `bundle install` (#820)
- Replace `consumer.consume` with `consumer.consumed` event to match the behaviour
- Make sure, that offset committing happens before the `consumer.consumed` event is propagated
- Fix for failing when not installed (just a dependency) (#817)
- Evict messages from partitions that were lost upon rebalancing (#825)
- Do **not** run `#revoked` on partitions that were lost and assigned back upon rebalancing (#825)
- Remove potential duplicated that could occur upon rebalance with re-assigned partitions (#825)
- Optimize integration test suite additional consumers shutdown process (#828)
- Optimize messages eviction and duplicates removal on poll stopped due to lack of messages
- Add static group membership integration spec

## 2.0.0-alpha5 (2022-04-03)
- Rename StdoutListener to LoggerListener (#811)

## 2.0.0-alpha4 (2022-03-20)
- Rails support without ActiveJob queue adapter usage (#805)

## 2.0.0-alpha3 (2022-03-16)
- Restore 'app.initialized' state and add notification on it
- Fix the installation flow for Rails and add integration tests for this scenario
- Add more integration tests covering some edge cases

## 2.0.0-alpha2 (2022-02-19)
- Require `kafka` keys to be symbols
- [Pro] Added ActiveJob Pro adapter
- Small updates to the license and docs

## 2.0.0-alpha1 (2022-01-30)
- Change license to `LGPL-3.0`
- [Pro] Introduce a Pro subscription
- Switch from `ruby-kafka` to `librdkafka` as an underlying driver
- Introduce fully automatic integration tests that go through the whole server lifecycle
- Integrate WaterDrop tightly with autoconfiguration inheritance and an option to redefine it
- Multi-threaded support for concurrent jobs consumption (when in separate topics and/or partitions)
- Introduce subscriptions groups concept for better resources management
- Remove completely all the callbacks in favour of finalizer method `#on_shutdown`
- Provide `on_revoked` method for taking actions upon topic revoke
- Remove single message consumption mode in favour of documentation on how to do it easily by yourself
- Provide sync and async offset management with async preferred
- Introduce seamless Ruby on Rails integration via `Rails::Railte`
- Update `cli info` to reflect the `2.0` details
- Remove responders in favour of WaterDrop `2.0` producer
- Remove pidfiles support
- Remove daemonization support
- Stop validating `kafka` configuration beyond minimum as it is handled by `librdkafka`
- Remove topics mappers concept
- Reorganize monitoring to match new concepts
- Notify on fatal worker processing errors
- Rename `Karafka::Params::BatchMetadata` to `Karafka::Messages::BatchMetadata`
- Rename `Karafka::Params::Params` to `Karafka::Messages::Message`
- Rename `#params_batch` in consumers to `#messages`
- Rename `Karafka::Params::Metadata` to `Karafka::Messages::Metadata`
- Allow for processing work of multiple consumer groups by the same worker poll
- Rename `Karafka::Fetcher` to `Karafka::Runner` and align notifications key names
- Update install templates
- `sidekiq-backend` is no longer supported
- `testing` gem for RSpec has been updated
- `WaterDrop` `2.1+` support
- Simple routing style (`0.5`) now builds a single consumer group instead of one per topic
- Example apps were updated
- Hook for underlying statistics emitted from librdkafka have been added
- Hook for underlying async errors emitted from  librdkafka have been added
- ActiveJob Rails adapter
- Added benchmarks that can be used to profile Karafka
- Standardize error hook for all error reporting

## 1.4.11 (2021-12-04)
- Source code metadata url added to the gemspec
- Gem bump

## 1.4.10 (2021-10-30)
- update gems requirements in the gemspec (nijikon)

## 1.4.9 (2021-09-29)
- fix `dry-configurable` deprecation warnings for default value as positional argument

## 1.4.8 (2021-09-08)
- Allow 'rails' in Gemfile to enable rails-aware generator (rewritten)

## 1.4.7 (2021-09-04)
- Update ruby-kafka to `1.4.0`
- Support for `resolve_seed_brokers` option (with Azdaroth)
- Set minimum `ruby-kafka` requirement to `1.3.0`

## 1.4.6 (2021-08-05)
- #700 Fix Ruby 3 compatibility issues in Connection::Client#pause (MmKolodziej)

## 1.4.5 (2021-06-16)
- Fixup logger checks for non-writeable logfile (ojab)
- #689 - Update the stdout initialization message for framework initialization

## 1.4.4 (2021-04-19)
- Remove Ruby 2.5 support and update minimum Ruby requirement to 2.6
- Remove rake dependency

## 1.4.3 (2021-03-24)
- Fixes for Ruby 3.0 compatibility

## 1.4.2 (2021-02-16)
- Rescue Errno::EROFS in ensure_dir_exists (unasuke)

## 1.4.1 (2020-12-04)
- Return non-zero exit code when printing usage
- Add support for :assignment_strategy for consumers

## 1.4.0 (2020-09-05)
- Rename `Karafka::Params::Metadata` to `Karafka::Params::BatchMetadata`
- Rename consumer `#metadata` to `#batch_metadata`
- Separate metadata (including Karafka native metadata) from the root of params (backwards compatibility preserved thanks to rabotyaga)
- Remove metadata hash dependency
- Remove params dependency on a hash in favour of PORO
- Remove batch metadata dependency on a hash
- Remove MultiJson in favour of JSON in the default deserializer
- allow accessing all the metadata without accessing the payload
- freeze params and underlying elements except for the mutable payload
- provide access to raw payload after serialization
- fixes a bug where a non-deserializable (error) params would be marked as deserialized after first unsuccessful deserialization attempt
- fixes bug where karafka would mutate internal ruby-kafka state
- fixes bug where topic name in metadata would not be mapped using topic mappers
- simplifies the params and params batch API, before `#payload` usage, it won't be deserialized
- removes the `#[]` API from params to prevent from accessing raw data in a different way than #raw_payload
- makes the params batch operations consistent as params payload is deserialized only when accessed explicitly

## 1.3.7 (2020-08-11)
- #599 - Allow metadata access without deserialization attempt (rabotyaga)
- Sync with ruby-kafka `1.2.0` api

## 1.3.6 (2020-04-24)
- #583 - Use Karafka.logger for CLI messages (prikha)
- #582 - Cannot only define seed brokers in consumer groups

## 1.3.5 (2020-04-02)
- #578 - ThreadError: can't be called from trap context patch

## 1.3.4 (2020-02-17)
- `dry-configurable` upgrade (solnic)
- Remove temporary `thor` patches that are no longer needed

## 1.3.3 (2019-12-23)
- Require `delegate` to fix missing dependency in `ruby-kafka`

## 1.3.2 (2019-12-23)
- #561 - Allow `thor` 1.0.x usage in Karafka
- #567 - Ruby 2.7.0 support + unfreeze of a frozen string fix

## 1.3.1 (2019-11-11)
- #545 - Makes sure the log directory exists when is possible (robertomiranda)
- Ruby 2.6.5 support
- #551 - add support for DSA keys
- #549 - Missing directories after `karafka install` (nijikon)

## 1.3.0 (2019-09-09)
- Drop support for Ruby 2.4
- YARD docs tags cleanup

## 1.3.0.rc1 (2019-07-31)
- Drop support for Kafka 0.10 in favor of native support for Kafka 0.11.
- Update ruby-kafka to the 0.7 version
- Support messages headers receiving
- Message bus unification
- Parser available in metadata
- Cleanup towards moving to a non-global state app management
- Drop Ruby 2.3 support
- Support for Ruby 2.6.3
- `Karafka::Loader` has been removed in favor of Zeitwerk
- Schemas are now contracts
- #393 - Reorganize responders - removed `multiple_usage` constrain
- #388 - ssl_client_cert_chain sync
- #300 - Store value in a value key and replace its content with parsed version - without root merge
- #331 - Disallow building groups without topics
- #340 - Instrumentation unification. Better and more consistent naming
- #340 - Procline instrumentation for a nicer process name
- #342 - Change default for `fetcher_max_queue_size` from `100` to `10` to lower max memory usage
- #345 - Cleanup exceptions names
- #341 - Split connection delegator into batch delegator and single_delegator
- #351 - Rename `#retrieve!` to `#parse!` on params and `#parsed` to `parse!` on params batch.
- #351 - Adds '#first' for params_batch that returns parsed first element from the params_batch object.
- #360 - Single params consuming mode automatically parses data specs
- #359 - Divide mark_as_consumed into mark_as_consumed and mark_as_consumed!
- #356 - Provide a `#values` for params_batch to extract only values of objects from the params_batch
- #363 - Too shallow ruby-kafka version lock
- #354 - Expose consumer heartbeat
- #377 - Remove the persistent setup in favor of persistence
- #375 - Sidekiq Backend parser mismatch
- #369 - Single consumer can support more than one topic
- #288 - Drop dependency on `activesupport` gem
- #371 - SASL over SSL
- #392 - Move params redundant data to metadata
- #335 - Metadata access from within the consumer
- #402 - Delayed reconnection upon critical failures
- #405 - `reconnect_timeout` value is now being validated
- #437 - Specs ensuring that the `#437` won't occur in the `1.3` release
- #426 - ssl client cert key password
- #444 - add certificate and private key validation
- #460 - Decouple responder "parser" (generator?) from topic.parser (benissimo)
- #463 - Split parsers into serializers / deserializers
- #473 - Support SASL OAuthBearer Authentication
- #475 - Disallow subscribing to the same topic with multiple consumers
- #485 - Setting shutdown_timeout to nil kills the app without waiting for anything
- #487 - Make listeners as instances
- #29 - Consumer class names must have the word "Consumer" in it in order to work (Sidekiq backend)
- #491 - irb is missing for console to work
- #502 - Karafka process hangs when sending multiple sigkills
- #506 - ssl_verify_hostname sync
- #483 - Upgrade dry-validation before releasing 1.3
- #492 - Use Zeitwerk for code reload in development
- #508 - Reset the consumers instances upon reconnecting to a cluster
- [#530](https://github.com/karafka/karafka/pull/530) - expose ruby and ruby-kafka version
- [534](https://github.com/karafka/karafka/pull/534) - Allow to use headers in the deserializer object
- [#319](https://github.com/karafka/karafka/pull/328) - Support for exponential backoff in pause

## 1.2.11
- [#470](https://github.com/karafka/karafka/issues/470) Karafka not working with dry-configurable 0.8

## 1.2.10
- [#453](https://github.com/karafka/karafka/pull/453) require `Forwardable` module

## 1.2.9
- Critical exceptions now will cause consumer to stop instead of retrying without a break
- #412 - Fix dry-inflector dependency lock in gemspec
- #414 - Backport to 1.2 the delayed retry upon failure
- #437 - Raw message is no longer added to params after ParserError raised

## 1.2.8
- #408 - Responder Topic Lookup Bug on Heroku

## 1.2.7
- Unlock Ruby-kafka version with a warning

## 1.2.6
- Lock WaterDrop to 1.2.3
- Lock Ruby-Kafka to 0.6.x (support for 0.7 will be added in Karafka 1.3)
- #382 - Full logging with AR, etc for development mode when there is Rails integration

## 1.2.5
- #354 - Expose consumer heartbeat
- #373 - Async producer not working properly with responders

## 1.2.4
- #332 - Fetcher for max queue size

## 1.2.3
- #313 - support PLAINTEXT and SSL for scheme
- #288 - drop activesupport callbacks in favor of notifications
- #320 - Pausing indefinitely with nil pause timeout doesn't work
- #318 - Partition pausing doesn't work with custom topic mappers
- Rename ConfigAdapter to ApiAdapter to better reflect what it does
- #317 - Manual offset committing doesn't work with custom topic mappers

## 1.2.2
- #312 - Broken for ActiveSupport 5.2.0

## 1.2.1
- #304 - Unification of error instrumentation event details
- #306 - Using file logger from within a trap context upon shutdown is impossible

## 1.2.0
- Spec improvements
- #260 - Specs missing randomization
- #251 - Shutdown upon non responding (unreachable) cluster is not possible
- #258 - Investigate lowering requirements on activesupport
- #246 - Alias consumer#mark_as_consumed on controller
- #259 - Allow forcing key/partition key on responders
- #267 - Styling inconsistency
- #242 - Support setting the max bytes to fetch per request
- #247 - Support SCRAM once released
- #271 - Provide an after_init option to pass a configuration block
- #262 - Error in the monitor code for NewRelic
- #241 - Performance metrics
- #274 - Rename controllers to consumers
- #184 - Seek to
- #284 - Dynamic Params parent class
- #275 - ssl_ca_certs_from_system
- #296 - Instrument forceful exit with an error
- Replaced some of the activesupport parts with dry-inflector
- Lower ActiveSupport dependency
- Remove configurators in favor of the after_init block configurator
- Ruby 2.5.0 support
- Renamed Karafka::Connection::Processor to Karafka::Connection::Delegator to match incoming naming conventions
- Renamed Karafka::Connection::Consumer to Karafka::Connection::Client due to #274
- Removed HashWithIndifferentAccess in favor of a regular hash
- JSON parsing defaults now to string keys
- Lower memory usage due to less params data internal details
- Support multiple ```after_init``` blocks in favor of a single one
- Renamed ```received_at``` to ```receive_time``` to follow ruby-kafka and WaterDrop conventions
- Adjust internal setup to easier map Ruby-Kafka config changes
- System callbacks reorganization
- Added ```before_fetch_loop``` configuration block for early client usage (```#seek```, etc)
- Renamed ```after_fetched``` to ```after_fetch``` to normalize the naming convention
- Instrumentation on a connection delegator level
- Added ```params_batch#last``` method to retrieve last element after unparsing
- All params keys are now strings

## 1.1.2
- #256 - Default kafka.seed_brokers configuration is created in invalid format

## 1.1.1
- #253 - Allow providing a global per app parser in config settings

## 1.1.0
- Gem bump
- Switch from Celluloid to native Thread management
- Improved shutdown process
- Introduced optional fetch callbacks and moved current the ```after_received``` there as well
- Karafka will raise Errors::InvalidPauseTimeout exception when trying to pause but timeout set to 0
- Allow float for timeouts and other time based second settings
- Renamed MessagesProcessor to Processor and MessagesConsumer to Consumer - we don't process and don't consumer anything else so it was pointless to keep this "namespace"
- #232 - Remove unused ActiveSupport require
- #214 - Expose consumer on a controller layer
- #193 - Process shutdown callbacks
- Fixed accessibility of ```#params_batch``` from the outside of the controller
- connection_pool config options are no longer required
- celluloid config options are no longer required
- ```#perform``` is now renamed to ```#consume``` with warning level on using the old one (deprecated)
- #235 - Rename perform to consume
- Upgrade to ruby-kafka 0.5
- Due to redesign of Waterdrop concurrency setting is no longer needed
- #236 - Manual offset management
- WaterDrop 1.0.0 support with async
- Renamed ```batch_consuming``` option to ```batch_fetching``` as it is not a consumption (with processing) but a process of fetching messages from Kafka. The messages is considered consumed, when it is processed.
- Renamed ```batch_processing``` to ```batch_consuming``` to resemble Kafka concept of consuming messages.
- Renamed ```after_received``` to ```after_fetched``` to normalize the naming conventions.
- Responders support the per topic ```async``` option.

## 1.0.1
- #210 - LoadError: cannot load such file -- [...]/karafka.rb
- Ruby 2.4.2 as a default (+travis integration)
- JRuby upgrade
- Expanded persistence layer (moved to a namespace for easier future development)
- #213 - Misleading error when non-existing dependency is required
- #212 - Make params react to #topic, #partition, #offset
- #215 - Consumer group route dynamic options are ignored
- #217 - check RUBY_ENGINE constant if RUBY_VERSION is missing (#217)
- #218 - add configuration setting to control Celluloid's shutdown timeout
- Renamed Karafka::Routing::Mapper to Karafka::Routing::TopicMapper to match naming conventions
- #219 - Allow explicit consumer group names, without prefixes
- Fix to early removed pid upon shutdown of demonized process
- max_wait_time updated to match https://github.com/zendesk/ruby-kafka/issues/433
- #230 - Better uri validation for seed brokers (incompatibility as the kafka:// or kafka+ssl:// is required)
- Small internal docs fixes
- Dry::Validation::MissingMessageError: message for broker_schema? was not found
- #238 - warning: already initialized constant Karafka::Schemas::URI_SCHEMES

## 1.0.0

### Closed issues:

- #103 - Env for logger is loaded 2 early (on gem load not on app init)
- #142 - Possibility to better control Kafka consumers (consumer groups management)
- #150 - Add support for start_from_beginning on a per topic basis
- #154 - Support for min_bytes and max_wait_time on messages consuming
- #160 - Reorganize settings to better resemble ruby-kafka requirements
- #164 - If we decide to have configuration per topic, topic uniqueness should be removed
- #165 - Router validator
- #166 - Params and route reorganization (new API)
- #167 - Remove Sidekiq UI from Karafka
- #168 - Introduce unique IDs of routes
- #171 - Add kafka message metadata to params
- #176 - Transform Karafka::Connection::Consumer into a module
- #177 - Monitor not reacting when kafka killed with -9
- #175 - Allow single consumer to subscribe to multiple topics
- #178 - Remove parsing failover when cannot unparse data
- #174 - Extended config validation
- ~~#180 - Switch from JSON parser to yajl-ruby~~
- #181 - When responder is defined and not used due to ```respond_with``` not being triggered in the perform, it won't raise an exception.
- #188 - Rename name in config to client id
- #186 - Support ruby-kafka ```ssl_ca_cert_file_path``` config
- #189 - karafka console does not preserve history on exit
- #191 - Karafka 0.6.0rc1 does not work with jruby / now it does :-)
- Switch to multi json so everyone can use their favourite JSON parser
- Added jruby support in general and in Travis
- #196 - Topic mapper does not map topics when subscribing thanks to @webandtech
- #96 - Karafka server - possibility to run it only for a certain topics
- ~~karafka worker cli option is removed (please use sidekiq directly)~~ - restored, bad idea
- (optional) pausing upon processing failures ```pause_timeout```
- Karafka console main process no longer intercepts irb errors
- Wiki updates
- #204 - Long running controllers
- Better internal API to handle multiple usage cases using ```Karafka::Controllers::Includer```
- #207 - Rename before_enqueued to after_received
- #147 - De-attach Karafka from Sidekiq by extracting Sidekiq backend

### New features and improvements

- batch processing thanks to ```#batch_consuming``` flag and ```#params_batch``` on controllers
- ```#topic``` method on an controller instance to make a clear distinction in between params and route details
- Changed routing model (still compatible with 0.5) to allow better resources management
- Lower memory requirements due to object creation limitation (2-3 times less objects on each new message)
- Introduced the ```#batch_consuming``` config flag (config for #126) that can be set per each consumer_group
- Added support for partition, offset and partition key in the params hash
- ```name``` option in config renamed to ```client_id```
- Long running controllers with ```persistent``` flag on a topic config level, to make controller instances persistent between messages batches (single controller instance per topic per partition no per messages batch) - turned on by default

### Incompatibilities

- Default boot file is renamed from app.rb to karafka.rb
- Removed worker glass as dependency (now and independent gem)
- ```kafka.hosts``` option renamed to ```kafka.seed_brokers``` - you don't need to provide all the hosts to work with Kafka
- ```start_from_beginning``` moved into kafka scope (```kafka.start_from_beginning```)
- Router no longer checks for route uniqueness - now you can define same routes for multiple kafkas and do a lot of crazy stuff, so it's your responsibility to check uniqueness
- Change in the way we identify topics in between Karafka and Sidekiq workers. If you upgrade, please make sure, all the jobs scheduled in Sidekiq are finished before the upgrade.
- ```batch_mode``` renamed to ```batch_fetching```
- Renamed content to value to better resemble ruby-kafka internal messages naming convention
- When having a responder with ```required``` topics and not using ```#respond_with``` at all, it will raise an exception
- Renamed ```inline_mode``` to ```inline_processing``` to resemble other settings conventions
- Renamed ```inline_processing``` to ```backend``` to reach 1.0 future compatibility
- Single controller **needs** to be used for a single topic consumption
- Renamed ```before_enqueue``` to ```after_received``` to better resemble internal logic, since for inline backend, there is no enqueue.
- Due to the level on which topic and controller are related (class level), the dynamic worker selection is no longer available.
- Renamed params #retrieve to params #retrieve! to better reflect what it does

### Other changes
- PolishGeeksDevTools removed (in favour of Coditsu)
- Waaaaaay better code quality thanks to switching from dev tools to Coditsu
- Gem bump
- Cleaner internal API
- SRP
- Better settings proxying and management between ruby-kafka and karafka
- All internal validations are now powered by dry-validation
- Better naming conventions to reflect Kafka reality
- Removed Karafka::Connection::Message in favour of direct message details extraction from Kafka::FetchedMessage

## 0.5.0.3
- #132 - When Kafka is gone, should reconnect after a time period
- #136 - new ruby-kafka version + other gem bumps
- ruby-kafka update
- #135 - NonMatchingRouteError - better error description in the code
- #140 - Move Capistrano Karafka to a different specific gem
- #110 - Add call method on a responder class to alias instance build and call
- #76 - Configs validator
- #138 - Possibility to have no worker class defined if inline_mode is being used
- #145 - Topic Mapper
- Ruby update to 2.4.1
- Gem bump x2
- #158 - Update docs section on heroku usage
- #150 - Add support for start_from_beginning on a per topic basis
- #148 - Lower Karafka Sidekiq dependency
- Allow karafka root to be specified from ENV
- Handle SIGTERM as a shutdown command for kafka server to support Heroku deployment

## 0.5.0.2
- Gems update x3
- Default Ruby set to 2.3.3
- ~~Default Ruby set to 2.4.0~~
- Readme updates to match bug fixes and resolved issues
- #95 - Allow options into responder
- #98 - Use parser when responding on a topic
- #114 - Option to configure waterdrop connection pool timeout and concurrency
- #118 - Added dot in topic validation format
- #119 - add support for authentication using SSL
- #121 - JSON as a default for standalone responders usage
- #122 - Allow on capistrano role customization
- #125 - Add support to batch incoming messages
- #130 - start_from_beginning flag on routes and default
- #128 - Monitor caller_label not working with super on inheritance
- Renamed *inline* to *inline_mode* to stay consistent with flags that change the way karafka works (#125)
- Dry-configurable bump to 0.5 with fixed proc value evaluation on retrieve patch (internal change)

## 0.5.0.1
- Fixed inconsistency in responders non-required topic definition. Now only required: false available
- #101 - Responders fail when multiple_usage true and required false
- fix error on startup from waterdrop #102
- Waterdrop 0.3.2.1 with kafka.hosts instead of kafka_hosts
- #105 - Karafka::Monitor#caller_label not working with inherited monitors
- #99 - Standalone mode (without Sidekiq)
- #97 - Buffer responders single topics before send (pre-validation)
- Better control over consumer thanks to additional config options
- #111 - Dynamic worker assignment based on the income params
- Long shutdown time fix

## 0.5.0
- Removed Zookeeper totally as dependency
- Better group and partition rebalancing
- Automatic thread management (no need for tuning) - each topic is a separate actor/thread
- Moved from Poseidon into Ruby-Kafka
- No more max_concurrency setting
- After you define your App class and routes (and everything else) you need to add execute App.boot!
- Manual consuming is no longer available (no more karafka consume command)
- Karafka topics CLI is no longer available. No Zookeeper - no global topic discovery
- Dropped ZK as dependency
- karafka info command no longer prints details about Zookeeper
- Better shutdown
- No more autodiscovery via Zookeeper - instead, the whole cluster will be discovered directly from Kafka
- No more support for Kafka 0.8
- Support for Kafka 0.9
- No more need for ActorCluster, since now we have a single thread (and Kafka connection) per topic
- Ruby 2.2.* support dropped
- Using App name as a Kafka client_id
- Automatic Capistrano integration
- Responders support for handling better responses pipe-lining and better responses flow description and design (see README for more details)
- Gem bump
- Readme updates
- karafka flow CLI command for printing the application flow
- Some internal refactoring

## 0.4.2
- #87 - Re-consume mode with crone for better Rails/Rack integration
- Moved Karafka server related stuff into separate Karafka::Server class
- Renamed Karafka::Runner into Karafka::Fetcher
- Gem bump
- Added chroot option to Zookeeper options
- Moved BROKERS_PATH into config from constant
- Added Karafka consume CLI action for a short running single consumption round
- Small fixes to close broken connections
- Readme updates

## 0.4.1
- Explicit throw(:abort) required to halt before_enqueue (like in Rails 5)
- #61 - autodiscovery of Kafka brokers based on Zookeeper data
- #63 - Graceful shutdown with current offset state during data processing
- #65 - Example of NewRelic monitor is outdated
- #71 - Setup should be executed after user code is loaded
- Gem bump x3
- Rubocop remarks
- worker_timeout config option has been removed. It now needs to be defined manually by the framework user because WorkerGlass::Timeout can be disabled and we cannot use Karafka settings on a class level to initialize user code stuff
- Moved setup logic under setup/Setup namespace
- Better defaults handling
- #75 - Kafka and Zookeeper options as a hash
- #82 - Karafka autodiscovery fails upon caching of configs
- #81 - Switch config management to dry configurable
- Version fix
- Dropped support for Ruby 2.1.*
- Ruby bump to 2.3.1

## 0.4.0
- Added WaterDrop gem with default configuration
- Refactoring of config logic to simplify adding new dependencies that need to be configured based on #setup data
- Gem bump
- Readme updates
- Renamed cluster to actor_cluster for method names
- Replaced SidekiqGlass with generic WorkerGlass lib
- Application bootstrap in app.rb no longer required
- Karafka.boot needs to be executed after all the application files are loaded (template updated)
- Small loader refactor (no API changes)
- Ruby 2.3.0 support (default)
- No more rake tasks
- Karafka CLI instead of rake tasks
- Worker cli command allows passing additional options directly to Sidekiq
- Renamed concurrency to max_concurrency - it describes better what happens - Karafka will use this number of threads only when required
- Added wait_timeout that allows us to tune how long should we wait on a single socket connection (single topic) for new messages before going to next one (this applies to each thread separately)
- Rubocop remarks
- Removed Sinatra and Puma dependencies
- Karafka Cli internal reorganization
- Karafka Cli routes task
- #37 - warn log for failed parsing of a message
- #43 - wrong constant name
- #44 - Method name conflict
- #48 - Cannot load such file -- celluloid/current
- #46 - Loading application
- #45 - Set up monitor in config
- #47 - rake karafka:run uses app.rb only
- #53 - README update with Sinatra/Rails integration description
- #41 - New Routing engine
- #54 - Move Karafka::Workers::BaseWorker to Karafka::BaseWorker
- #55 - ApplicationController and ApplicationWorker

## 0.3.2
- Karafka::Params::Params lazy load merge keys with string/symbol names priorities fix

## 0.3.1
- Renamed Karafka::Monitor to Karafka::Process to represent a Karafka process wrapper
- Added Karafka::Monitoring that allows to add custom logging and monitoring with external libraries and systems
- Moved logging functionality into Karafka::Monitoring default monitoring
- Added possibility to provide own monitoring as long as in responds to #notice and #notice_error
- Standardized logging format for all logs

## 0.3.0
- Switched from custom ParserError for each parser to general catching of Karafka::Errors::ParseError and its descendants
- Gem bump
- Fixed #32 - now when using custom workers that does not inherit from Karafka::BaseWorker perform method is not required. Using custom workers means that the logic that would normally lie under #perform, needs to be executed directly from the worker.
- Fixed #31 - Technically didn't fix because this is how Sidekiq is meant to work, but provided possibility to assign custom interchangers that allow to bypass JSON encoding issues by converting data that goes to Redis to a required format (and parsing it back when it is fetched)
- Added full parameters lazy load - content is no longer loaded during #perform_async if params are not used in before_enqueue
- No more namespaces for Redis by default (use separate DBs)

## 0.1.21
- Sidekiq 4.0.1 bump
- Gem bump
- Added direct celluloid requirement to Karafka (removed from Sidekiq)

## 0.1.19
- Internal call - schedule naming change
- Enqueue to perform_async naming in controller to follow Sidekiq naming convention
- Gem bump

## 0.1.18
- Changed Redis configuration options into a single hash that is directly passed to Redis setup for Sidekiq
- Added config.ru to provide a Sidekiq web UI (see README for more details)

## 0.1.17
- Changed Karafka::Connection::Cluster tp Karafka::Connection::ActorCluster to distinguish between a single thread actor cluster for multiple topic connection and a future feature that will allow process clusterization.
- Add an ability to use user-defined parsers for a messages
- Lazy load params for before callbacks
- Automatic loading/initializing all workers classes during startup (so Sidekiq won't fail with unknown workers exception)
- Params are now private to controller
- Added bootstrap method to app.rb

## 0.1.16
- Cluster level error catching for all exceptions so actor is not killer
- Cluster level error logging
- Listener refactoring (QueueConsumer extracted)
- Karafka::Connection::QueueConsumer to wrap around fetching logic - technically we could replace Kafka with any other messaging engine as long as we preserve the same API
- Added debug env for debugging purpose in applications

## 0.1.15
- Fixed max_wait_ms vs socket_timeout_ms issue
- Fixed closing queue connection after Poseidon::Errors::ProtocolError failure
- Fixed wrong logging file selection based on env
- Extracted Karafka::Connection::QueueConsumer object to wrap around queue connection

## 0.1.14
- Rake tasks for listing all the topics on Kafka server (rake kafka:topics)

## 0.1.13
- Ability to assign custom workers and use them bypassing Karafka::BaseWorker (or its descendants)
- Gem bump

## 0.1.12
- All internal errors went to Karafka::Errors namespace

## 0.1.11
- Rescuing all the "before Sidekiq" processing so errors won't affect other incoming messages
- Fixed dying actors after connection error
- Added a new app status - "initializing"
- Karafka::Status model cleanup

## 0.1.10
- Added possibility to specify redis namespace in configuration (failover to app name)
- Renamed redis_host to redis_url in configuration

## 0.1.9
- Added worker logger

## 0.1.8
- Dropped local env support in favour of [Envlogic](https://github.com/karafka/envlogic) - no changes in API

## 0.1.7
- Karafka option for Redis hosts (not localhost only)

## 0.1.6
- Added better concurency by clusterization of listeners
- Added graceful shutdown
- Added concurency that allows to handle bigger applications with celluloid
- Karafka controllers no longer require group to be defined (created based on the topic and app name)
- Karafka controllers no longer require topic to be defined (created based on the controller name)
- Readme updates

## 0.1.5
- Celluloid support for listeners
- Multi target logging (STDOUT and file)

## 0.1.4
- Renamed events to messages to follow Apache Kafka naming convention

## 0.1.3
- Karafka::App.logger moved to Karafka.logger
- README updates (Usage section was added)

## 0.1.2
- Logging to log/environment.log
- Karafka::Runner

## 0.1.1
- README updates
- Rake tasks updates
- Rake installation task
- Changelog file added

## 0.1.0
- Initial framework code
