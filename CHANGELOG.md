# Karafka framework changelog

## 2.1.0 (Unreleased)
- **[Feature]** Introduce collective Virtual Partitions offset management.
- **[Feature]** Use virtual offsets to filter out messages that would be re-processed upon retries.
- [Improvement] No longer break processing on failing parallel virtual partitions in ActiveJob because it is compensated by virtual marking.
- [Improvement] Always use Virtual offset management for Pro ActiveJobs.
- [Improvement] Do not attempt to mark offsets on already revoked partitions.
- [Improvement] Make sure, that VP components are not injected into non VP strategies.
- [Improvement] Improve complex strategies inheritance flow.
- [Improvement] Optimize offset management for DLQ + MoM feature combinations.
- [Change] Removed `Karafka::Pro::BaseConsumer` in favor of `Karafka::BaseConsumer`. (#1345)

### Upgrade notes

1. Replace `Karafka::Pro::BaseConsumer` references to `Karafka::BaseConsumer`.

## 2.0.41 (2023-14-19)
- **[Feature]** Provide `Karafka::Pro::Iterator` for anonymous topic/partitions iterations and messages lookups (#1389 and #1427).
- [Improvement] Optimize topic lookup for `read_topic` admin method usage.
- [Improvement] Report via `LoggerListener` information about the partition on which a given job has started and finished.
- [Improvement] Slightly normalize the `LoggerListener` format. Always report partition related operations as followed: `TOPIC_NAME/PARTITION`.
- [Improvement] Do not retry recovery from `unknown_topic_or_part` when Karafka is shutting down as there is no point and no risk of any data losses.
- [Improvement] Report `client.software.name` and `client.software.version` according to `librdkafka` recommendation.
- [Improvement] Report ten longest integration specs after the suite execution.
- [Improvement] Prevent user originating errors related to statistics processing after listener loop crash from potentially crashing the listener loop and hanging Karafka process.

## 2.0.40 (2023-04-13)
- [Improvement] Introduce `Karafka::Messages::Messages#empty?` method to handle Idle related cases where shutdown or revocation would be called on an empty messages set. This method allows for checking if there are any messages in the messages batch.
- [Refactor] Require messages builder to accept partition and do not fetch it from messages.
- [Refactor] Use empty messages set for internal APIs (Idle) (so there always is `Karafka::Messages::Messages`)
- [Refactor] Allow for empty messages set initialization with -1001 and -1 on metadata (similar to `librdkafka`)

## 2.0.39 (2023-04-11)
- **[Feature]** Provide ability to throttle/limit number of messages processed in a time unit (#1203)
- **[Feature]** Provide Delayed Topics (#1000)
- **[Feature]** Provide ability to expire messages (expiring topics)
- **[Feature]** Provide ability to apply filters after messages are polled and before enqueued. This is a generic filter API for any usage.
- [Improvement] When using ActiveJob with Virtual Partitions, Karafka will stop if collectively VPs are failing. This minimizes number of jobs that will be collectively re-processed.
- [Improvement] `#retrying?` method has been added to consumers to provide ability to check, that we're reprocessing data after a failure. This is useful for branching out processing based on errors.
- [Improvement] Track active_job_id in instrumentation (#1372)
- [Improvement] Introduce new housekeeping job type called `Idle` for non-consumption execution flows.
- [Improvement] Change how a manual offset management works with Long-Running Jobs. Use the last message offset to move forward instead of relying on the last message marked as consumed for a scenario where no message is marked.
- [Improvement] Prioritize in Pro non-consumption jobs execution over consumption despite LJF. This will ensure, that housekeeping as well as other non-consumption events are not saturated when running a lot of work.
- [Improvement] Normalize the DLQ behaviour with MoM. Always pause on dispatch for all the strategies.
- [Improvement] Improve the manual offset management and DLQ behaviour when no markings occur for OSS.
- [Improvement] Do not early stop ActiveJob work running under virtual partitions to prevent extensive reprocessing.
- [Improvement] Drastically increase number of scenarios covered by integration specs (OSS and Pro).
- [Improvement] Introduce a `Coordinator#synchronize` lock for cross virtual partitions operations.
- [Fix] Do not resume partition that is not paused.
- [Fix] Fix `LoggerListener` cases where logs would not include caller id (when available)
- [Fix] Fix not working benchmark tests.
- [Fix] Fix a case where when using manual offset management with a user pause would ignore the pause and seek to the next message.
- [Fix] Fix a case where dead letter queue would go into an infinite loop on message with first ever offset if the first ever offset would not recover.
- [Fix] Make sure to resume always for all LRJ strategies on revocation.
- [Refactor] Make sure that coordinator is topic aware. Needed for throttling, delayed processing and expired jobs.
- [Refactor] Put Pro strategies into namespaces to better organize multiple combinations.
- [Refactor] Do not rely on messages metadata for internal topic and partition operations like `#seek` so they can run independently from the consumption flow.
- [Refactor] Hold a single topic/partition reference on a coordinator instead of in executor, coordinator and consumer.
- [Refactor] Move `#mark_as_consumed` and `#mark_as_consumed!`into `Strategies::Default` to be able to introduce marking for virtual partitions.

## 2.0.38 (2023-03-27)
- [Improvement] Introduce `Karafka::Admin#read_watermark_offsets` to get low and high watermark offsets values.
- [Improvement] Track active_job_id in instrumentation (#1372)
- [Improvement] Improve `#read_topic` reading in case of a compacted partition where the offset is below the low watermark offset. This should optimize reading and should not go beyond the low watermark offset.
- [Improvement] Allow `#read_topic` to accept instance settings to overwrite any settings needed to customize reading behaviours.

## 2.0.37 (2023-03-20)
- [Fix] Declarative topics execution on a secondary cluster run topics creation on the primary one (#1365)
- [Fix]  Admin read operations commit offset when not needed (#1369)

## 2.0.36 (2023-03-17)
- [Refactor] Rename internal naming of `Structurable` to `Declaratives` for declarative topics feature.
- [Fix] AJ + DLQ + MOM + LRJ is pausing indefinitely after the first job (#1362)

## 2.0.35 (2023-03-13)
- **[Feature]** Allow for defining topics config via the DSL and its automatic creation via CLI command.
- **[Feature]** Allow for full topics reset and topics repartitioning via the CLI.

## 2.0.34 (2023-03-04)
- [Improvement] Attach an `embedded` tag to Karafka processes started using the embedded API.
- [Change] Renamed `Datadog::Listener` to `Datadog::MetricsListener` for consistency. (#1124)

### Upgrade notes

1. Replace `Datadog::Listener` references to `Datadog::MetricsListener`.

## 2.0.33 (2023-02-24)
- **[Feature]** Support `perform_all_later` in ActiveJob adapter for Rails `7.1+`
- **[Feature]** Introduce ability to assign and re-assign tags in consumer instances. This can be used for extra instrumentation that is context aware.
- **[Feature]** Introduce ability to assign and reassign tags to the `Karafka::Process`.
- [Improvement] When using `ActiveJob` adapter, automatically tag jobs with the name of the `ActiveJob` class that is running inside of the `ActiveJob` consumer.
- [Improvement] Make `::Karafka::Instrumentation::Notifications::EVENTS` list public for anyone wanting to re-bind those into a different notification bus.
- [Improvement] Set `fetch.message.max.bytes` for `Karafka::Admin` to `5MB` to make sure that all data is fetched correctly for Web UI under heavy load (many consumers).
- [Improvement] Introduce a `strict_topics_namespacing` config option to enable/disable the strict topics naming validations. This can be useful when working with pre-existing topics which we cannot or do not want to rename.
- [Fix] Karafka monitor is prematurely cached (#1314)

### Upgrade notes

Since `#tags` were introduced on consumers, the `#tags` method is now part of the consumers API.

This means, that in case you were using a method called `#tags` in your consumers, you will have to rename it:

```ruby
class EventsConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      tags << message.payload.tag
    end

    tags.each { |tags| puts tag }
  end

  private

  # This will collide with the tagging API
  # This NEEDS to be renamed not to collide with `#tags` method provided by the consumers API.
  def tags
    @tags ||= Set.new
  end
end
```

## 2.0.32 (2023-02-13)
- [Fix] Many non-existing topic subscriptions propagate poll errors beyond client
- [Improvement] Ignore `unknown_topic_or_part` errors in dev when `allow.auto.create.topics` is on.
- [Improvement] Optimize temporary errors handling in polling for a better backoff policy

## 2.0.31 (2023-02-12)
- [Feature] Allow for adding partitions via `Admin#create_partitions` API.
- [Fix] Do not ignore admin errors upon invalid configuration (#1254)
- [Fix] Topic name validation (#1300) - CandyFet
- [Improvement] Increase the `max_wait_timeout` on admin operations to five minutes to make sure no timeout on heavily loaded clusters.
- [Maintenance] Require `karafka-core` >= `2.0.11` and switch to shared RSpec locator.
- [Maintenance] Require `karafka-rdkafka` >= `0.12.1`

## 2.0.30 (2023-01-31)
- [Improvement] Alias `--consumer-groups` with `--include-consumer-groups`
- [Improvement] Alias `--subscription-groups` with `--include-subscription-groups`
- [Improvement] Alias `--topics` with `--include-topics`
- [Improvement] Introduce `--exclude-consumer-groups` for ability to exclude certain consumer groups from running
- [Improvement] Introduce `--exclude-subscription-groups` for ability to exclude certain subscription groups from running
- [Improvement] Introduce `--exclude-topics` for ability to exclude certain topics from running

## 2.0.29 (2023-01-30)
- [Improvement] Make sure, that the `Karafka#producer` instance has the `LoggerListener` enabled in the install template, so Karafka by default prints both consumer and producer info.
- [Improvement] Extract the code loading capabilities of Karafka console from the executable, so web can use it to provide CLI commands.
- [Fix] Fix for: running karafka console results in NameError with Rails (#1280)
- [Fix] Make sure, that the `caller` for async errors is being published.
- [Change] Make sure that WaterDrop `2.4.10` or higher is used with this release to support Web-UI.

## 2.0.28 (2023-01-25)
- **[Feature]** Provide the ability to use Dead Letter Queue with Virtual Partitions.
- [Improvement] Collapse Virtual Partitions upon retryable error to a single partition. This allows dead letter queue to operate and mitigate issues arising from work virtualization. This removes uncertainties upon errors that can be retried and processed. Affects given topic partition virtualization only for multi-topic and multi-partition parallelization. It also minimizes potential "flickering" where given data set has potentially many corrupted messages. The collapse will last until all the messages from the collective corrupted batch are processed. After that, virtualization will resume.
- [Improvement] Introduce `#collapsed?` consumer method available for consumers using Virtual Partitions.
- [Improvement] Allow for customization of DLQ dispatched message details in Pro (#1266) via the `#enhance_dlq_message` consumer method.
- [Improvement] Include `original_consumer_group` in the DLQ dispatched messages in Pro.
- [Improvement] Use Karafka `client_id` as kafka `client.id` value by default

### Upgrade notes

If you want to continue to use `karafka` as default for kafka `client.id`, assign it manually:

```ruby
class KarafkaApp < Karafka::App
  setup do |config|
    # Other settings...
    config.kafka = {
      'client.id': 'karafka'
    }
```

## 2.0.27 (2023-01-11)
- Do not lock Ruby version in Karafka in favour of `karafka-core`.
- Make sure `karafka-core` version is at least `2.0.9` to make sure we run `karafka-rdkafka`.

## 2.0.26 (2023-01-10)
- **[Feature]** Allow for disabling given topics by setting `active` to false. It will exclude them from consumption but will allow to have their definitions for using admin APIs, etc.
- [Improvement] Early terminate on `read_topic` when reaching the last offset available on the request time.
- [Improvement] Introduce a `quiet` state that indicates that Karafka is not only moving to quiet mode but actually that it reached it and no work will happen anymore in any of the consumer groups.
- [Improvement] Use Karafka defined routes topics when possible for `read_topic` admin API.
- [Improvement] Introduce `client.pause` and `client.resume` instrumentation hooks for tracking client topic partition pausing and resuming. This is alongside of `consumer.consuming.pause` that can be used to track both manual and automatic pausing with more granular consumer related details. The `client.*` should be used for low level tracking.
- [Improvement] Replace `LoggerListener` pause notification with one based on `client.pause` instead of `consumer.consuming.pause`.
- [Improvement] Expand `LoggerListener` with `client.resume` notification.
- [Improvement] Replace random anonymous subscription groups ids with stable once.
- [Improvement] Add `consumer.consume`, `consumer.revoke` and `consumer.shutting_down` notification events and move the revocation logic calling to strategies.
- [Change] Rename job queue statistics `processing` key to `busy`. No changes needed because naming in the DataDog listener stays the same.
- [Fix] Fix proctitle listener state changes reporting on new states.
- [Fix] Make sure all files descriptors are closed in the integration specs.
- [Fix] Fix a case where empty subscription groups could leak into the execution flow.
- [Fix] Fix `LoggerListener` reporting so it does not end with `.`.
- [Fix] Run previously defined (if any) signal traps created prior to Karafka signals traps.

## 2.0.25 (2023-01-10)
- Release yanked due to accidental release with local changes.

## 2.0.24 (2022-12-19)
- **[Feature]** Provide out of the box encryption support for Pro.
- [Improvement] Add instrumentation upon `#pause`.
- [Improvement] Add instrumentation upon retries.
- [Improvement] Assign `#id` to consumers similar to other entities for ease of debugging.
- [Improvement] Add retries and pausing to the default `LoggerListener`.
- [Improvement] Introduce a new final `terminated` state that will kick in prior to exit but after all the instrumentation and other things are done.
- [Improvement] Ensure that state transitions are thread-safe and ensure state transitions can occur in one direction.
- [Improvement] Optimize status methods proxying to `Karafka::App`.
- [Improvement] Allow for easier state usage by introducing explicit `#to_s` for reporting.
- [Improvement] Change auto-generated id from `SecureRandom#uuid` to `SecureRandom#hex(6)`
- [Improvement] Emit statistic every 5 seconds by default.
- [Improvement] Introduce general messages parser that can be swapped when needed.
- [Fix] Do not trigger code reloading when `consumer_persistence` is enabled.
- [Fix] Shutdown producer after all the consumer components are down and the status is stopped. This will ensure, that any instrumentation related Kafka messaging can still operate.

### Upgrade notes

If you want to disable `librdkafka` statistics because you do not use them at all, update the `kafka` `statistics.interval.ms` setting and set it to `0`:

```ruby
class KarafkaApp < Karafka::App
  setup do |config|
    # Other settings...
    config.kafka = {
      'statistics.interval.ms': 0
    }
  end
end
```

## 2.0.23 (2022-12-07)
- [Maintenance] Align with `waterdrop` and `karafka-core`
- [Improvement] Provide `Admin#read_topic` API to get topic data without subscribing.
- [Improvement] Upon an end user `#pause`, do not commit the offset in automatic offset management mode. This will prevent from a scenario where pause is needed but during it a rebalance occurs and a different assigned process starts not from the pause location but from the automatic offset that may be different. This still allows for using the `#mark_as_consumed`.
- [Fix] Fix a scenario where manual `#pause` would be overwritten by a resume initiated by the strategy.
- [Fix] Fix a scenario where manual `#pause` in LRJ would cause infinite pause.

## 2.0.22 (2022-12-02)
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

## Older releases

This changelog tracks Karafka `2.0` and higher changes.

If you are looking for changes in the unsupported releases, we recommend checking the [`1.4`](https://github.com/karafka/karafka/blob/1.4/CHANGELOG.md) branch of the Karafka repository.
