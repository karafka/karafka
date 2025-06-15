# Karafka Framework Changelog

## 2.5.0 (2025-06-15)
- **[Breaking]** Change how consistency of DLQ dispatches works in Pro (`partition_key` vs. direct partition id mapping).
- **[Breaking]** Remove the headers `source_key` from the Pro DLQ dispatched messages as the original key is now fully preserved.
- **[Breaking]** Use DLQ and Piping prefix `source_` instead of `original_` to align with naming convention of Kafka Streams and Apache Flink for future usage.
- **[Breaking]** Rename scheduled jobs topics names in their config (Pro).
- **[Breaking]** Change K8s listener response from `204` to `200` and include JSON body with reasons.
- **[Breaking]** Replace admin config `max_attempts` with `max_retries_duration` and 
- **[Feature]** Parallel Segments for concurrent processing of the same partition with more than partition count of processes (Pro).
- [Enhancement] Normalize topic + partition logs format.
- [Enhancement] Support KIP-82 (header values of arrays).
- [Enhancement] Enhance errors tracker with `#counts` that contains per-error class specific counters for granular flow handling.
- [Enhancement] Provide explicit `Karafka::Admin.copy_consumer_group` API.
- [Enhancement] Return explicit value from `Karafka::Admin.copy_consumer_group` and `Karafka::Admin.rename_consumer_group` APIs.
- [Enhancement] Introduce balanced non-consistent VP distributor improving the utilization up to 50% (Pro).
- [Enhancement] Make the error tracker for advanced DLQ strategies respond to `#topic` and `#partition` for context aware dispatches.
- [Enhancement] Allow setting the workers thread priority and set it to -1 (50ms) by default.
- [Enhancement] Enhance low-level `client.pause` event with timeout value (if provided).
- [Enhancement] Introduce `#marking_cursor` API (defaults to `#cursor`) in the filtering API (Pro).
- [Enhancement] Support multiple DLQ target topics via context aware strategies (Pro).
- [Enhancement] Raise error when post-transactional committing of offset is done outside of the transaction (Pro).
- [Enhancement] Include info level rebalance logger listener data.
- [Enhancement] Include info level subscription start info.
- [Enhancement] Make the generic error handling in the `LoggerListener` more descriptive by logging also the error class.
- [Enhancement] Allow marking older offsets to support advanced rewind capabilities.
- [Enhancement] Change optional `#seek` reset offset flag default to `true` as `false` is almost never used and seek by default should move the internal consumer offset position as well.
- [Enhancement] Include Swarm node ID in the swarm process tags.
- [Enhancement] Replace internal usage of MD5 with SHA256 for FIPS.
- [Enhancement] Improve OSS vs. Pro specs execution isolation.
- [Enhancement] Preload `librdkafka` code prior to forking in the Swarm mode to save memory.
- [Enhancement] Extract errors tracker class reference into an internal `errors_tracker_class` config option (Pro).
- [Enhancement] Support rdkafka native kafka polling customization for admin.
- [Enhancement] Customize the multiplexing scale delay (Pro) per consumer group (Pro).
- [Enhancement] Set `topic.metadata.refresh.interval.ms` for default producer in dev to 5s to align with consumer setup.
- [Enhancement] Alias `-2` and `-1` with `latest` and `earliest` for seeking.
- [Enhancement] Allow for usage of `latest` and `earliest` in the `Karafka::Pro::Iterator`.
- [Enhancement] Failures during `topics migrate` (and other subcommands) don't show what topic failed, and why it's invalid.
- [Enhancement] Apply changes to topics configuration in atomic independent requests when using Declarative Topics.
- [Enhancement] Execute the help CLI command when no command provided (similar to Rails) to improve DX.
- [Enhancement] Remove backtrace from the CLI error for incorrect commands (similar to Rails) to improve DX.
- [Enhancement] Provide `karafka topics help` sub-help due to nesting of Declarative Topics actions.
- [Enhancement] Use independent keys for different states of reporting in scheduled messages.
- [Enhancement] Enrich scheduled messages state reporter with debug data.
- [Enhancement] Introduce a new state called `stopped` to the scheduled messages.
- [Enhancement] Do not overwrite the `key` in the Pro DLQ dispatched messages for routing reasons.
- [Enhancement] Introduce `errors_tracker.trace_id` for distributed error details correlation with the Web UI.
- [Enhancement] Improve contracts validations reporting.
- [Enhancement] Optimize topic creation and repartitioning admin operations for topics with hundreds of partitions.
- [Refactor] Introduce a `bin/verify_kafka_warnings` script to clean Kafka from temporary test-suite topics.
- [Refactor] Introduce a `bin/verify_topics_naming` script to ensure proper test topics naming convention.
- [Refactor] Make sure all temporary topics have a `it-` prefix in their name.
- [Refactor] Improve CI specs parallelization.
- [Maintenance] Lower the `Karafka::Admin` `poll_timeout` to 50 ms to improve responsiveness of admin operations.
- [Maintenance] Require `karafka-rdkafka` `>=` `0.19.5` due to usage of `#rd_kafka_global_init`, KIP-82, new producer caching engine and improvements to the `partition_key` assignments.
- [Maintenance] Add Deimos routing patch into integration suite not to break it in the future.
- [Maintenance] Remove Rails `7.0` specs due to upcoming EOL.
- [Fix] Fix Recurring Tasks and Scheduled Messages not working with Swarm (using closed producer).
- [Fix] Fix a case where `unknown_topic_or_part` error could leak out of the consumer on consumer shutdown.
- [Fix] Fix missing `virtual_partitions.partitioner.error` custom error logging in the `LoggerListener`.
- [Fix] Prevent applied system filters `#timeout` from potentially interacting with user filters.
- [Fix] Use more sane value in `Admin#seek_consumer_group` for long ago.
- [Fix] Prevent multiplexing of 1:1 from routing.
- [Fix] WaterDrop level aborting transaction may cause seek offset to move (Pro).
- [Fix] Fix inconsistency in the logs where `Karafka::Server` originating logs would not have server id reference.
- [Fix] Fix inconsistency in the logs where OS signal originating logs would not have server id reference.
- [Fix] Post-fork WaterDrop instance looses some of the non-kafka settings.
- [Fix] Max epoch tracking for early cleanup causes messages to be skipped until reload.
- [Fix] optparse double parse loses ARGV.
- [Fix] `karafka` cannot be required without Bundler.
- [Fix] Scheduled Messages re-seek moves to `latest` on inheritance of initial offset when `0` offset is compacted.
- [Fix] Seek to `:latest` without `topic_partition_position` (-1) will not seek at all.
- [Fix] Extremely high turn over of scheduled messages can cause them not to reach EOF/Loaded state.
- [Fix] Fix incorrectly passed `max_wait_time` to rdkafka (ms instead of seconds) causing too long wait.
- [Fix] Remove aggresive requerying of the Kafka cluster on topic creation/removal/altering.
- [Change] Move to trusted-publishers and remove signing since no longer needed.

## 2.4.18 (2025-04-09)
- [Fix] Make sure `Bundler.with_unbundled_env` is not called multiple times.

## 2.4.17 (2025-01-15)
- [Enhancement] Clean message key and headers when cleaning messages via the cleaner API (Pro).
- [Enhancement] Allow for setting `metadata: false` in the cleaner API for granular cleaning control (Pro)
- [Enhancement] Instrument successful transaction via `consumer.consuming.transaction` event (Pro).

## 2.4.16 (2024-12-27)
- [Enhancement] Improve post-rebalance revocation messages filtering.
- [Enhancement] Introduce `Consumer#wrap` for connection pooling management and other wrapped operations.
- [Enhancement] Guard transactional operations from marking beyond assignment ownership under some extreme edge-cases.
- [Enhancement] Improve VPs work with transactional producers.
- [Enhancement] Prevent non-transactional operations leakage into transactional managed offset management consumers.
- [Fix] Prevent transactions from being marked with a non-transactional default producer when automatic offset management and other advanced features are on.
- [Fix] Fix `kafka_format` `KeyError` that occurs when a non-hash is assigned to the kafka scope of the settings.
- [Fix] Non cooperative-sticky transactional offset management can refetch reclaimed partitions.

## 2.4.15 (2024-12-04)
- [Fix] Assignment tracker current state fetch during a rebalance loop can cause an error on multi CG setup.
- [Fix] Prevent double post-transaction offset dispatch to Kafka.

## 2.4.14 (2024-11-25)
- [Enhancement] Improve low-level critical error reporting.
- [Enhancement] Expand Kubernetes Liveness state reporting with critical errors detection.
- [Enhancement] Save several string allocations and one array allocation on each job execution when using Datadog instrumentation.
- [Enhancement] Support `eofed` jobs in the AppSignal instrumentation.
- [Enhancement] Allow running bootfile-less Rails setup Karafka CLI commands where stuff is configured in the initializers.
- [Fix] `Instrumentation::Vendors::Datadog::LoggerListener` treats eof jobs as consume jobs.

## 2.4.13 (2024-10-11)
- [Enhancement] Make declarative topics return different exit codes on migrable/non-migrable states (0 - no changes, 2 - changes) when used with `--detailed-exitcode` flag.
- [Enhancement] Introduce `config.strict_declarative_topics` that should force declaratives on all non-pattern based topics and DLQ topics
- [Enhancement] Report ignored repartitioning to lower number of partitions in declarative topics.
- [Enhancement] Promote the `LivenessListener#healty?` to a public API.
- [Fix] Fix `Karafka::Errors::MissingBootFileError` when debugging in VScode with ruby-lsp.
- [Fix] Require `karafka-core` `>=` `2.4.4` to prevent dependencies conflicts. 
- [Fix] Validate swarm cli and always parse options from argv (roelbondoc)

## 2.4.12 (2024-09-17)
- **[Feature]** Provide Adaptive Iterator feature as a fast alternative to Long-Running Jobs (Pro).
- [Enhancement] Provide `Consumer#each` as a delegation to messages batch.
- [Enhancement] Verify cancellation request envelope topic similar to the schedule one.
- [Enhancement] Validate presence of `bootstrap.servers` to avoid incomplete partial reconfiguration.
- [Enhancement] Support `ActiveJob#enqueue_at` via Scheduled Messages feature (Pro).
- [Enhancement] Introduce `Karafka::App#debug!` that will switch Karafka and the default producer into extensive debug mode. Useful for CLI debugging.
- [Enhancement] Support full overwrite of the `BaseConsumer#producer`.
- [Enhancement] Transfer the time of last poll back to the coordinator for more accurate metrics tracking.
- [Enhancement] Instrument `Consumer#seek` via `consumer.consuming.seek`.
- [Fix] Fix incorrect time reference reload in scheduled messages.

## 2.4.11 (2024-09-04)
- [Enhancement] Validate envelope target topic type for Scheduled Messages.
- [Enhancement] Support for enqueue_after_transaction_commit in rails active job.
- [Fix] Fix invalid reference to AppSignal version.

## 2.4.10 (2024-09-03)
- **[Feature]** Provide Kafka based Scheduled Messages to be able to send messages in the future via a proxy topic.
- [Enhancement] Introduce a `#assigned` hook for consumers to be able to trigger actions when consumer is built and assigned but before first consume/ticking, etc.
- [Enhancement] Provide `Karafka::Messages::Message#tombstone?` to be able to quickly check if a message is a tombstone message.
- [Enhancement] Provide more flexible API for Recurring Tasks topics reconfiguration.
- [Enhancement] Remove no longer needed Rails connection releaser.
- [Enhancement] Update AppSignal client to support newer versions (tombruijn and hieuk09).
- [Fix] Fix a case where there would be a way to define multiple subscription groups for same topic with different consumer.

## 2.4.9 (2024-08-23)
- **[Feature]** Provide Kafka based Recurring (Cron) Tasks.
- [Enhancement] Wrap worker work with Rails Reloader/Executor (fusion2004)
- [Enhancement] Allow for partial topic level kafka scope settings reconfiguration via `inherit` flag.
- [Enhancement] Validate `eof` kafka scope flag when `eofed` in routing enabled.
- [Enhancement] Provide `mark_after_dispatch` setting for granular DLQ marking control.
- [Enhancement] Provide `Karafka::Admin.rename_consumer_group`.

## 2.4.8 (2024-08-09)
- **[Feature]** Introduce ability to react to `#eof` either from `#consume` or from `#eofed` when EOF without new messages.
- [Enhancement] Provide `Consumer#eofed?` to indicate reaching EOF.
- [Enhancement] Always immediately report on `inconsistent_group_protocol` error.
- [Enhancement] Reduce virtual partitioning to 1 partition when any partitioner execution in a partitioned batch crashes.
- [Enhancement] Provide `KARAFKA_REQUIRE_RAILS` to disable default Rails `require` to run Karafka without Rails despite having Rails in the Gemfile.
- [Enhancement] Increase final listener recovery from 1 to 60 seconds to prevent constant rebalancing. This is the last resort recovery and should never happen unless critical errors occur.

## 2.4.7 (2024-08-01)
- [Enhancement] Introduce `Karafka::Server.execution_mode` to check in what mode Karafka process operates (`standalone`, `swarm`, `supervisor`, `embedded`).
- [Enhancement] Ensure `max.poll.interval.ms` is always present and populate it with librdkafka default.
- [Enhancement] Introduce a shutdown time limit for unsubscription wait.
- [Enhancement] Tag with `mode:swarm` each of the running swarm consumers.
- [Change] Tag with `mode:embedded` instead of `embedded` the embedded consumers.
- [Fix] License identifier `LGPL-3.0` is deprecated for SPDX (#2177).
- [Fix] Fix an issue where custom clusters would not have default settings populated same as the primary cluster.
- [Fix] Fix Rspec warnings of nil mocks.
- [Maintenance] Cover `cooperative-sticky` librdkafka issues with integration spec.

## 2.4.6 (2024-07-22)
- [Fix] Mitigate `rd_kafka_cgrp_terminated` and other `librdkafka` shutdown issues by unsubscribing fully prior to shutdown.

## 2.4.5 (2024-07-18)
- [Change] Inject `client.id` when building subscription group and not during the initial setup.
- [Fix] Mitigate `confluentinc/librdkafka/issues/4783` by injecting dynamic client id when using `cooperative-sticky` strategy.

### Change Note

`client.id` is technically a low-importance value that should not (aside from this error) impact operations. This is why it is not considered a breaking change. This change may be reverted when the original issue is fixed in librdkafka.

## 2.4.4 (2024-07-04)
- [Enhancement] Allow for offset storing from the Filtering API.
- [Enhancement] Print more extensive error info on forceful shutdown.
- [Enhancement] Include `original_key` in the DLQ dispatch headers.
- [Enhancement] Support embedding mode control management from the trap context.
- [Enhancement] Make sure, that the listener thread is stopped before restarting.
- [Fix] Do not block on hanging listener shutdown when invoking forceful shutdown.
- [Fix] Static membership fencing error is not propagated explicitly enough.
- [Fix] Make sure DLQ dispatches raw headers and not deserialized headers (same as payload).
- [Fix] Fix a typo where `ms` in logger listener would not have space before it.
- [Maintenance] Require `karafka-core` `>=` `2.4.3`.
- [Maintenance] Allow for usage of `karafka-rdkafka` `~` `0.16` to support librdkafka `2.4.0`.
- [Maintenance] Lower the precision reporting to 100 microseconds in the logger listener.

## 2.4.3 (2024-06-12)
- [Enhancement] Allow for customization of Virtual Partitions reducer for enhanced parallelization.
- [Enhancement] Add more error codes to early report on polling issues (kidlab)
- [Enhancement] Add `transport`, `network_exception` and `coordinator_load_in_progress` alongside `timed_out` to retryable errors for the proxy.
- [Enhancement] Improve `strict_topics_namespacing` validation message.
- [Change] Remove default empty thread name from `Async` since Web has been upgraded.
- [Fix] Installer doesn't respect directories in `KARAFKA_BOOT_FILE`.
- [Fix] Fix case where non absolute boot file path would not work as expected.
- [Fix] Allow for installing Karafka in a non-existing (yet) directory
- [Maintenance] Require `waterdrop` `>=` `2.7.3` to support idempotent producer detection.

## 2.4.2 (2024-05-14)
- [Enhancement] Validate ActiveJob adapter custom producer format.
- [Fix] Internal seek does not resolve the offset correctly for time based lookup.

## 2.4.1 (2024-05-10)
- [Enhancement] Allow for usage of producer variants and alternative producers with ActiveJob Jobs (Pro).
- [Enhancement] Support `:earliest` and `:latest` in `Karafka::Admin#seek_consumer_group`.
- [Enhancement] Align configuration attributes mapper with exact librdkafka version used and not master.
- [Maintenance] Use `base64` from RubyGems as it will no longer be part of standard library in Ruby 3.4.
- [Fix] Support migrating via aliases and plan with aliases usage.
- [Fix] Active with default set to `false` cannot be overwritten
- [Fix] Fix inheritance of ActiveJob adapter `karafka_options` partitioner and dispatch method.

## 2.4.0 (2024-04-26)

This release contains **BREAKING** changes. Make sure to read and apply upgrade notes.

- **[Breaking]** Drop Ruby `2.7` support.
- **[Breaking]** Drop the concept of consumer group mapping.
- **[Breaking]** `karafka topics migrate` will now perform declarative topics configuration alignment.
- **[Breaking]** Replace `deserializer` config with `#deserializers` in routing to support key and lazy header deserializers.
- **[Breaking]** Rename `Karafka::Serializers::JSON::Deserializer` to `Karafka::Deserializers::Payload` to reflect its role.
- **[Feature]** Support custom OAuth providers (with a lot of help from bruce-szalwinski-he and hotelengine.com).
- **[Feature]** Provide `karafka topics alter` for declarative topics alignment.
- **[Feature]** Introduce ability to use direct assignments (Pro).
- **[Feature]** Provide consumer piping API (Pro).
- **[Feature]** Introduce `karafka topics plan` to describe changes that will be applied when migrating.
- **[Feature]** Introduce ability to use custom message key deserializers.
- **[Feature]** Introduce ability to use custom message headers deserializers.
- **[Feature]** Provide `Karafka::Admin::Configs` API for cluster and topics configuration management.
- [Enhancement] Protect critical `rdkafka` thread executable code sections.
- [Enhancement] Assign names to internal threads for better debuggability when on `TTIN`.
- [Enhancement] Provide `log_polling` setting to the `Karafka::Instrumentation::LoggerListener` to silence polling in any non-debug mode.
- [Enhancement] Provide `metadata#message` to be able to retrieve message from metadata.
- [Enhancement] Include number of attempts prior to DLQ message being dispatched including the dispatch one (Pro).
- [Enhancement] Provide ability to decide how to dispatch from DLQ (sync / async).
- [Enhancement] Provide ability to decide how to mark as consumed from DLQ (sync / async).
- [Enhancement] Allow for usage of a custom Appsignal namespace when logging.
- [Enhancement] Do not run periodic jobs when LRJ job is running despite polling (LRJ can still start when Periodic runs).
- [Enhancement] Improve accuracy of periodic jobs and make sure they do not run too early after saturated work.
- [Enhancement] Introduce ability to async lock other subscription groups polling.
- [Enhancement] Improve shutdown when using long polling setup (high `max_wait_time`).
- [Enhancement] Provide `Karafka::Admin#read_lags_with_offsets` for ability to query lags and offsets of a given CG.
- [Enhancement] Allow direct assignments granular distribution in the Swarm (Pro).
- [Enhancement] Add a buffer to the supervisor supervision on shutdown to prevent a potential race condition when signal pass lags.
- [Enhancement] Provide ability to automatically generate and validate fingerprints of encrypted payload.
- [Enhancement] Support `enable.partition.eof` fast yielding.
- [Enhancement] Provide `#mark_as_consumed` and `#mark_as_consumed!` to the iterator.
- [Enhancement] Introduce graceful `#stop` to the iterator instead of recommending of usage of `break`.
- [Enhancement] Do not run jobs schedulers and other interval based operations on each job queue unlock.
- [Enhancement] Publish listeners status lifecycle events.
- [Enhancement] Use proxy wrapper for Admin metadata requests.
- [Enhancement] Use limited scope topic info data when operating on direct topics instead of full cluster queries.
- [Enhancement] No longer raise `Karafka::UnsupportedCaseError` for not recognized error types to support dynamic errors reporting.
- [Change] Do not create new proxy object to Rdkafka with certain low-level operations and re-use existing.
- [Change] Update `karafka.erb` template with a placeholder for waterdrop and karafka error instrumentation.
- [Change] Replace `statistics.emitted.error` error type with `callbacks.statistics.error` to align naming conventions.
- [Fix] Pro Swarm liveness listener can report incorrect failure when dynamic multiplexing scales down.
- [Fix] K8s liveness listener can report incorrect failure when dynamic multiplexing scales down.
- [Fix] Fix a case where connection conductor would not be released during manager state changes.
- [Fix] Make sure, that all `Admin` operations go through stabilization proxy.
- [Fix] Fix an issue where coordinator running jobs would not count periodic jobs and revocations.
- [Fix] Fix a case where critically crashed supervisor would raise incorrect error.
- [Fix] Re-raise critical supervisor errors before shutdown.
- [Fix] Fix a case when right-open (infinite) swarm matching would not pass validations.
- [Fix] Make `#enqueue_all` output compatible with `ActiveJob.perform_all_later` (oozzal)
- [Fix] Seek consumer group on a topic level is updating only recent partition.

### Upgrade Notes

**PLEASE MAKE SURE TO READ AND APPLY THEM!**

Available [here](https://karafka.io/docs/Upgrades-2.4/).

## 2.3.4 (2024-04-11)

- [Fix] Seek consumer group on a topic level is updating only recent partition.

## 2.3.3 (2024-02-26)
- [Enhancement] Routing based topics allocation for swarm (Pro)
- [Enhancement] Publish the `-1` shutdown reason status for a non-responding node in swarm.
- [Enhancement] Allow for using the `distribution` mode for DataDog listener histogram reporting (Aerdayne).
- [Change] Change `internal.swarm.node_report_timeout` to 60 seconds from 30 seconds to compensate for long pollings.
- [Fix] Static membership routing evaluation happens too early in swarm.
- [Fix] Close producer in supervisor prior to forking and warmup to prevent invalid memory states.

## 2.3.2 (2024-02-16)
- **[Feature]** Provide swarm capabilities to OSS and Pro.
- **[Feature]** Provide ability to use complex strategies in DLQ (Pro).
- [Enhancement] Support using `:partition` as the partition key for ActiveJob assignments.
- [Enhancement] Expand Logger listener with swarm notifications.
- [Enhancement] Introduce K8s swarm liveness listener.
- [Enhancement] Use `Process.warmup` in Ruby 3.3+ prior to forks (in swarm) and prior to app start.
- [Enhancement] Provide `app.before_warmup` event to allow hooking code loading tools prior to final warmup.
- [Enhancement] Provide `Consumer#errors_tracker` to be able to get errors that occurred while doing complex recovery.
- [Fix] Infinite consecutive error flow with VPs and without DLQ can cause endless offsets accumulation.
- [Fix] Quieting mode causes too early unsubscribe.

## 2.3.1 (2024-02-08)
- [Refactor] Ensure that `Karafka::Helpers::Async#async_call` can run from multiple threads.

## 2.3.0 (2024-01-26)
- **[Feature]** Introduce Exactly-Once Semantics within consumers `#transaction` block (Pro)
- **[Feature]** Provide ability to multiplex subscription groups (Pro)
- **[Feature]** Provide `Karafka::Admin::Acl` for Kafka ACL management via the Admin APIs.
- **[Feature]** Periodic Jobs (Pro)
- **[Feature]** Offset Metadata storage (Pro)
- **[Feature]** Provide low-level listeners management API for dynamic resources scaling (Pro)
- [Enhancement] Improve shutdown process by allowing for parallel connections shutdown.
- [Enhancement] Introduce `non_blocking` routing API that aliases LRJ to indicate a different use-case for LRJ flow approach.
- [Enhancement] Allow to reset offset when seeking backwards by using the `reset_offset` keyword attribute set to `true`.
- [Enhancement] Alias producer operations in consumer to skip `#producer` reference.
- [Enhancement] Provide an `:independent` configuration to DLQ allowing to reset pause count track on each marking as consumed when retrying.
- [Enhancement] Remove no longer needed shutdown patches for `librdkafka` improving multi-sg shutdown times for `cooperative-sticky`.
- [Enhancement] Allow for parallel closing of connections from independent consumer groups.
- [Enhancement] Provide recovery flow for cases where DLQ dispatch would fail.
- [Change] Make `Kubernetes::LivenessListener` not start until Karafka app starts running.
- [Change] Remove the legacy "inside of topics" way of defining subscription groups names
- [Change] Update supported instrumentation to report on `#tick`.
- [Refactor] Replace `define_method` with `class_eval` in some locations.
- [Fix] Fix a case where internal Idle job scheduling would go via the consumption flow.
- [Fix] Make the Iterator `#stop_partition` work with karafka-rdkafka `0.14.6`.
- [Fix] Ensure Pro components are not loaded during OSS specs execution (not affecting usage).
- [Fix] Fix invalid action label for consumers in DataDog logger instrumentation.
- [Fix] Fix a scenario where `Karafka::Admin#seek_consumer_group` would fail because reaching not the coordinator.
- [Ignore] option --include-consumer-groups not working as intended after removal of "thor"

### Upgrade Notes

Available [here](https://karafka.io/docs/Upgrades-2.3/).

## 2.2.14 (2023-12-07)
- **[Feature]** Provide `Karafka::Admin#delete_consumer_group` and `Karafka::Admin#seek_consumer_group`.
- **[Feature]** Provide `Karafka::App.assignments` that will return real-time assignments tracking.
- [Enhancement] Make sure that the Scheduling API is thread-safe by default and allow for lock-less schedulers when schedulers are stateless.
- [Enhancement] "Blockless" topics with defaults
- [Enhancement] Provide a `finished?` method to the jobs for advanced reference based job schedulers.
- [Enhancement] Provide `client.reset` notification event.
- [Enhancement] Remove all usage of concurrent-ruby from Karafka
- [Change] Replace single #before_schedule with appropriate methods and events for scheduling various types of work. This is needed as we may run different framework logic on those and, second, for accurate job tracking with advanced schedulers.
- [Change] Rename `before_enqueue` to `before_schedule` to reflect what it does and when (internal).
- [Change] Remove not needed error catchers for strategies code. This code if errors, should be considered critical and should not be silenced.
- [Change] Remove not used notifications events.

## 2.2.13 (2023-11-17)
- **[Feature]** Introduce low-level extended Scheduling API for granular control of schedulers and jobs execution [Pro].
- [Enhancement] Use separate lock for user-facing synchronization.
- [Enhancement] Instrument `consumer.before_enqueue`.
- [Enhancement] Limit usage of `concurrent-ruby` (plan to remove it as a dependency fully)
- [Enhancement] Provide `#synchronize` API same as in VPs for LRJs to allow for lifecycle events and consumption synchronization.

## 2.2.12 (2023-11-09)
- [Enhancement] Rewrite the polling engine to update statistics and error callbacks despite longer non LRJ processing or long `max_wait_time` setups. This change provides stability to the statistics and background error emitting making them time-reliable.
- [Enhancement] Auto-update Inline Insights if new insights are present for all consumers and not only LRJ (OSS and Pro).
- [Enhancement] Alias `#insights` with `#inline_insights` and `#insights?` with `#inline_insights?`

## 2.2.11 (2023-11-03)
- [Enhancement] Allow marking as consumed in the user `#synchronize` block.
- [Enhancement] Make whole Pro VP marking as consumed concurrency safe for both async and sync scenarios.
- [Enhancement] Provide new alias to `karafka server`, that is: `karafka consumer`.

## 2.2.10 (2023-11-02)
- [Enhancement] Allow for running `#pause` without specifying the offset (provide offset or `:consecutive`). This allows for pausing on the consecutive message (last received + 1), so after resume we will get last message received + 1 effectively not using `#seek` and not purging `librdafka` buffer preserving on networking. Please be mindful that this uses notion of last message passed from **librdkafka**, and not the last one available in the consumer (`messages.last`). While for regular cases they will be the same, when using things like DLQ, LRJs, VPs or Filtering API, those may not be the same.
- [Enhancement] **Drastically** improve network efficiency of operating with LRJ by using the `:consecutive` offset as default strategy for running LRJs without moving the offset in place and purging the data.
- [Enhancement] Do not "seek in place". When pausing and/or seeking to the same location as the current position, do nothing not to purge buffers and not to move to the same place where we are.
- [Fix] Pattern regexps should not be part of declaratives even when configured.

### Upgrade Notes

In the latest Karafka release, there are no breaking changes. However, please note the updates to #pause and #seek. If you spot any issues, please report them immediately. Your feedback is crucial.

## 2.2.9 (2023-10-24)
- [Enhancement] Allow using negative offset references in `Karafka::Admin#read_topic`.
- [Change] Make sure that WaterDrop `2.6.10` or higher is used with this release to support transactions fully and the Web-UI.

## 2.2.8 (2023-10-20)
- **[Feature]** Introduce Appsignal integration for errors and metrics tracking.
- [Enhancement] Expose `#synchronize` for VPs to allow for locks when cross-VP consumers work is needed.
- [Enhancement] Provide `#collapse_until!` direct consumer API to allow for collapsed virtual partitions consumer operations together with the Filtering API for advanced use-cases.
- [Refactor] Reorganize how rebalance events are propagated from `librdkafka` to Karafka. Replace `connection.client.rebalance_callback` with `rebalance.partitions_assigned` and `rebalance.partitions_revoked`. Introduce two extra events: `rebalance.partitions_assign` and `rebalance.partitions_revoke` to handle pre-rebalance future work.
- [Refactor] Remove `thor` as a CLI layer and rely on Ruby `OptParser`

### Upgrade Notes

1. Unless you were using `connection.client.rebalance_callback` which was considered private, nothing.
2. None of the CLI commands should change but `thor` has been removed so please report if you find any bugs.

## 2.2.7 (2023-10-07)
- **[Feature]** Introduce Inline Insights to both OSS and Pro. Inline Insights allow you to get the Kafka insights/metrics from the consumer instance and use them to alter the processing flow. In Pro, there's an extra filter flow allowing to ensure, that the insights exist during consumption.
- [Enhancement] Make sure, that subscription groups ids are unique by including their consumer group id in them similar to how topics ids are handled (not a breaking change).
- [Enhancement] Expose `#attempt` method on a consumer to directly indicate number of attempt of processing given data.
- [Enhancement] Support Rails 7.1.

## 2.2.6 (2023-09-26)
- [Enhancement] Retry `Karafka::Admin#read_watermark_offsets` fetching upon `not_leader_for_partition` that can occur mostly on newly created topics in KRaft and after crashes during leader selection.

## 2.2.5 (2023-09-25)
- [Enhancement] Ensure, that when topic related operations end, the result is usable. There were few cases where admin operations on topics would finish successfully but internal Kafka caches would not report changes for a short period of time.
- [Enhancement] Stabilize cooperative-sticky early shutdown procedure.
- [Fix] use `#nil?` instead of `#present?` on `DataDog::Tracing::SpanOperation` (vitellochris)
- [Maintenance] Align connection clearing API with Rails 7.1 deprecation warning.
- [Maintenance] Make `#subscription_group` reference consistent in the Routing and Instrumentation.
- [Maintenance] Align the consumer pause instrumentation with client pause instrumentation by adding `subscription_group` visibility to the consumer.

## 2.2.4 (2023-09-13)
- [Enhancement] Compensate for potential Kafka cluster drifts vs consumer drift in batch metadata (#1611).

## 2.2.3 (2023-09-12)
- [Fix] Karafka admin time based offset lookup can break for one non-default partition.

## 2.2.2 (2023-09-11)
- [Feature] Provide ability to define routing defaults.
- [Maintenance] Require `karafka-core` `>=` `2.2.2`

## 2.2.1 (2023-09-01)
- [Fix] Fix insufficient validation of named patterns
- [Maintenance] Rely on `2.2.x` `karafka-core`.

## 2.2.0 (2023-09-01)
- **[Feature]** Introduce dynamic topic subscriptions based on patterns [Pro].
- [Enhancement] Allow for `Karafka::Admin` setup reconfiguration via `config.admin` scope.
- [Enhancement] Make sure that consumer group used by `Karafka::Admin` obeys the `ConsumerMapper` setup.
- [Fix] Fix a case where subscription group would not accept a symbol name.

### Upgrade Notes

As always, please make sure you have upgraded to the most recent version of `2.1` before upgrading to `2.2`.

If you are not using Kafka ACLs, there is no action you need to take.

If you are using Kafka ACLs and you've set up permissions for `karafka_admin` group, please note that this name has now been changed and is subject to [Consumer Name Mapping](https://karafka.io/docs/Consumer-mappers/).

That means you must ensure that the new consumer group that by default equals `CLIENT_ID_karafka_admin` has appropriate permissions. Please note that the Web UI also uses this group.

`Karafka::Admin` now has its own set of configuration options available, and you can find more details about that [here](https://karafka.io/docs/Topics-management-and-administration/#configuration).

If you want to maintain the `2.1` behavior, that is `karafka_admin` admin group, we recommend introducing this case inside your consumer mapper. Assuming you use the default one, the code will look as follows:

```ruby
  class MyMapper
    def call(raw_consumer_group_name)
      # If group is the admin one, use as it was in 2.1
      return 'karafka_admin' if raw_consumer_group_name == 'karafka_admin'

      # Otherwise use default karafka strategy for the rest
      "#{Karafka::App.config.client_id}_#{raw_consumer_group_name}"
    end
  end
```

## 2.1.13 (2023-08-28)
- **[Feature]** Introduce Cleaning API for much better memory management for iterative data processing [Pro].
- [Enhancement] Automatically free message resources after processed for ActiveJob jobs [Pro]
- [Enhancement] Free memory used by the raw payload as fast as possible after obtaining it from `karafka-rdkafka`.
- [Enhancement] Support changing `service_name` in DataDog integration.

## 2.1.12 (2023-08-25)
- [Fix] Fix a case where DLQ + VP without intermediate marking would mark earlier message then the last one.

## 2.1.11 (2023-08-23)
- [Enhancement] Expand the error handling for offset related queries with timeout error retries.
- [Enhancement] Allow for connection proxy timeouts configuration.

## 2.1.10 (2023-08-21)
- [Enhancement] Introduce `connection.client.rebalance_callback` event for instrumentation of rebalances.
- [Enhancement] Introduce new `runner.before_call` monitor event.
- [Refactor] Introduce low level commands proxy to handle deviation in how we want to run certain commands and how rdkafka-ruby runs that by design.
- [Change] No longer validate excluded topics routing presence if patterns any as it does not match pattern subscriptions where you can exclude things that could be subscribed in the future.
- [Fix] do not report negative lag stored in the DD listener.
- [Fix] Do not report lags in the DD listener for cases where the assignment is not workable.
- [Fix] Do not report negative lags in the DD listener.
- [Fix] Extremely fast shutdown after boot in specs can cause process not to stop.
- [Fix] Disable `allow.auto.create.topics` for admin by default to prevent accidental topics creation on topics metadata lookups.
- [Fix] Improve the `query_watermark_offsets` operations by increasing too low timeout.
- [Fix] Increase `TplBuilder` timeouts to compensate for remote clusters.
- [Fix] Always try to unsubscribe short-lived consumers used throughout the system, especially in the admin APIs.
- [Fix] Add missing `connection.client.poll.error` error type reference.

## 2.1.9 (2023-08-06)
- **[Feature]** Introduce ability to customize pause strategy on a per topic basis (Pro).
- [Enhancement] Disable the extensive messages logging in the default `karafka.rb` template.
- [Change] Require `waterdrop` `>= 2.6.6` due to extra `LoggerListener` API.

## 2.1.8 (2023-07-29)
- [Enhancement] Introduce `Karafka::BaseConsumer#used?` method to indicate, that at least one invocation of `#consume` took or will take place. This can be used as a replacement to the non-direct `messages.count` check for shutdown and revocation to ensure, that the consumption took place or is taking place (in case of running LRJ).
- [Enhancement] Make `messages#to_a` return copy of the underlying array to prevent scenarios, where the mutation impacts offset management.
- [Enhancement] Mitigate a librdkafka `cooperative-sticky` rebalance crash issue.
- [Enhancement] Provide ability to overwrite `consumer_persistence` per subscribed topic. This is mostly useful for plugins and extensions developers.
- [Fix] Fix a case where the performance tracker would crash in case of mutation of messages to an empty state.

## 2.1.7 (2023-07-22)
- [Enhancement] Always query for watermarks in the Iterator to improve the initial response time.
- [Enhancement] Add `max_wait_time` option to the Iterator.
- [Fix] Fix a case where `Admin#read_topic` would wait for poll interval on non-existing messages instead of early exit.
- [Fix] Fix a case where Iterator with per partition offsets with negative lookups would go below the number of available messages.
- [Fix] Remove unused constant from Admin module.
- [Fix] Add missing `connection.client.rebalance_callback.error` to the `LoggerListener` instrumentation hook.

## 2.1.6 (2023-06-29)
- [Enhancement] Provide time support for iterator
- [Enhancement] Provide time support for admin `#read_topic`
- [Enhancement] Provide time support for consumer `#seek`.
- [Enhancement] Remove no longer needed locks for client operations.
- [Enhancement] Raise `Karafka::Errors::TopicNotFoundError` when trying to iterate over non-existing topic.
- [Enhancement] Ensure that Kafka multi-command operations run under mutex together.
- [Change] Require `waterdrop` `>= 2.6.2`
- [Change] Require `karafka-core` `>= 2.1.1`
- [Refactor] Clean-up iterator code.
- [Fix]  Improve performance in dev environment for a Rails app (juike)
- [Fix] Rename `InvalidRealOffsetUsage` to `InvalidRealOffsetUsageError` to align with naming of other errors.
- [Fix] Fix unstable spec.
- [Fix] Fix a case where automatic `#seek` would overwrite manual seek of a user when running LRJ.
- [Fix] Make sure, that user direct `#seek` and `#pause` operations take precedence over system actions.
- [Fix] Make sure, that `#pause` and `#resume` with one underlying connection do not race-condition.

## 2.1.5 (2023-06-19)
- [Enhancement] Drastically improve `#revoked?` response quality by checking the real time assignment lost state on librdkafka.
- [Enhancement] Improve eviction of saturated jobs that would run on already revoked assignments.
- [Enhancement] Expose `#commit_offsets` and `#commit_offsets!` methods in the consumer to provide ability to commit offsets directly to Kafka without having to mark new messages as consumed.
- [Enhancement] No longer skip offset commit when no messages marked as consumed as `librdkafka` has fixed the crashes there.
- [Enhancement] Remove no longer needed patches.
- [Enhancement] Ensure, that the coordinator revocation status is switched upon revocation detection when using `#revoked?`
- [Enhancement] Add benchmarks for marking as consumed (sync and async).
- [Change] Require `karafka-core` `>= 2.1.0`
- [Change] Require `waterdrop` `>= 2.6.1`

## 2.1.4 (2023-06-06)
- [Fix] `processing_lag` and `consumption_lag` on empty batch fail on shutdown usage (#1475)

## 2.1.3 (2023-05-29)
- [Maintenance] Add linter to ensure, that all integration specs end with `_spec.rb`.
- [Fix] Fix `#retrying?` helper result value (Aerdayne).
- [Fix] Fix `mark_as_consumed!` raising an error instead of `false` on `unknown_member_id` (#1461).
- [Fix] Enable phantom tests.

## 2.1.2 (2023-05-26)
- Set minimum `karafka-core` on `2.0.13` to make sure correct version of `karafka-rdkafka` is used.
- Set minimum `waterdrop` on `2.5.3` to make sure correct version of `waterdrop` is used.

## 2.1.1 (2023-05-24)
- [Fix] Liveness Probe Doesn't Meet HTTP 1.1 Criteria - Causing Kubernetes Restarts (#1450)

## 2.1.0 (2023-05-22)
- **[Feature]** Provide ability to use CurrentAttributes with ActiveJob's Karafka adapter (federicomoretti).
- **[Feature]** Introduce collective Virtual Partitions offset management.
- **[Feature]** Use virtual offsets to filter out messages that would be re-processed upon retries.
- [Enhancement] No longer break processing on failing parallel virtual partitions in ActiveJob because it is compensated by virtual marking.
- [Enhancement] Always use Virtual offset management for Pro ActiveJobs.
- [Enhancement] Do not attempt to mark offsets on already revoked partitions.
- [Enhancement] Make sure, that VP components are not injected into non VP strategies.
- [Enhancement] Improve complex strategies inheritance flow.
- [Enhancement] Optimize offset management for DLQ + MoM feature combinations.
- [Change] Removed `Karafka::Pro::BaseConsumer` in favor of `Karafka::BaseConsumer`. (#1345)
- [Fix] Fix for `max_messages` and `max_wait_time` not having reference in errors.yml (#1443)

### Upgrade Notes

1. Upgrade to Karafka `2.0.41` prior to upgrading to `2.1.0`.
2. Replace `Karafka::Pro::BaseConsumer` references to `Karafka::BaseConsumer`.
3. Replace `Karafka::Instrumentation::Vendors::Datadog:Listener` with `Karafka::Instrumentation::Vendors::Datadog::MetricsListener`.

## 2.0.41 (2023-04-19)
- **[Feature]** Provide `Karafka::Pro::Iterator` for anonymous topic/partitions iterations and messages lookups (#1389 and #1427).
- [Enhancement] Optimize topic lookup for `read_topic` admin method usage.
- [Enhancement] Report via `LoggerListener` information about the partition on which a given job has started and finished.
- [Enhancement] Slightly normalize the `LoggerListener` format. Always report partition related operations as followed: `TOPIC_NAME/PARTITION`.
- [Enhancement] Do not retry recovery from `unknown_topic_or_part` when Karafka is shutting down as there is no point and no risk of any data losses.
- [Enhancement] Report `client.software.name` and `client.software.version` according to `librdkafka` recommendation.
- [Enhancement] Report ten longest integration specs after the suite execution.
- [Enhancement] Prevent user originating errors related to statistics processing after listener loop crash from potentially crashing the listener loop and hanging Karafka process.

## 2.0.40 (2023-04-13)
- [Enhancement] Introduce `Karafka::Messages::Messages#empty?` method to handle Idle related cases where shutdown or revocation would be called on an empty messages set. This method allows for checking if there are any messages in the messages batch.
- [Refactor] Require messages builder to accept partition and do not fetch it from messages.
- [Refactor] Use empty messages set for internal APIs (Idle) (so there always is `Karafka::Messages::Messages`)
- [Refactor] Allow for empty messages set initialization with -1001 and -1 on metadata (similar to `librdkafka`)

## 2.0.39 (2023-04-11)
- **[Feature]** Provide ability to throttle/limit number of messages processed in a time unit (#1203)
- **[Feature]** Provide Delayed Topics (#1000)
- **[Feature]** Provide ability to expire messages (expiring topics)
- **[Feature]** Provide ability to apply filters after messages are polled and before enqueued. This is a generic filter API for any usage.
- [Enhancement] When using ActiveJob with Virtual Partitions, Karafka will stop if collectively VPs are failing. This minimizes number of jobs that will be collectively re-processed.
- [Enhancement] `#retrying?` method has been added to consumers to provide ability to check, that we're reprocessing data after a failure. This is useful for branching out processing based on errors.
- [Enhancement] Track active_job_id in instrumentation (#1372)
- [Enhancement] Introduce new housekeeping job type called `Idle` for non-consumption execution flows.
- [Enhancement] Change how a manual offset management works with Long-Running Jobs. Use the last message offset to move forward instead of relying on the last message marked as consumed for a scenario where no message is marked.
- [Enhancement] Prioritize in Pro non-consumption jobs execution over consumption despite LJF. This will ensure, that housekeeping as well as other non-consumption events are not saturated when running a lot of work.
- [Enhancement] Normalize the DLQ behaviour with MoM. Always pause on dispatch for all the strategies.
- [Enhancement] Improve the manual offset management and DLQ behaviour when no markings occur for OSS.
- [Enhancement] Do not early stop ActiveJob work running under virtual partitions to prevent extensive reprocessing.
- [Enhancement] Drastically increase number of scenarios covered by integration specs (OSS and Pro).
- [Enhancement] Introduce a `Coordinator#synchronize` lock for cross virtual partitions operations.
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
- [Enhancement] Introduce `Karafka::Admin#read_watermark_offsets` to get low and high watermark offsets values.
- [Enhancement] Track active_job_id in instrumentation (#1372)
- [Enhancement] Improve `#read_topic` reading in case of a compacted partition where the offset is below the low watermark offset. This should optimize reading and should not go beyond the low watermark offset.
- [Enhancement] Allow `#read_topic` to accept instance settings to overwrite any settings needed to customize reading behaviours.

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
- [Enhancement] Attach an `embedded` tag to Karafka processes started using the embedded API.
- [Change] Renamed `Datadog::Listener` to `Datadog::MetricsListener` for consistency. (#1124)

### Upgrade Notes

1. Replace `Datadog::Listener` references to `Datadog::MetricsListener`.

## 2.0.33 (2023-02-24)
- **[Feature]** Support `perform_all_later` in ActiveJob adapter for Rails `7.1+`
- **[Feature]** Introduce ability to assign and re-assign tags in consumer instances. This can be used for extra instrumentation that is context aware.
- **[Feature]** Introduce ability to assign and reassign tags to the `Karafka::Process`.
- [Enhancement] When using `ActiveJob` adapter, automatically tag jobs with the name of the `ActiveJob` class that is running inside of the `ActiveJob` consumer.
- [Enhancement] Make `::Karafka::Instrumentation::Notifications::EVENTS` list public for anyone wanting to re-bind those into a different notification bus.
- [Enhancement] Set `fetch.message.max.bytes` for `Karafka::Admin` to `5MB` to make sure that all data is fetched correctly for Web UI under heavy load (many consumers).
- [Enhancement] Introduce a `strict_topics_namespacing` config option to enable/disable the strict topics naming validations. This can be useful when working with pre-existing topics which we cannot or do not want to rename.
- [Fix] Karafka monitor is prematurely cached (#1314)

### Upgrade Notes

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
- [Enhancement] Ignore `unknown_topic_or_part` errors in dev when `allow.auto.create.topics` is on.
- [Enhancement] Optimize temporary errors handling in polling for a better backoff policy

## 2.0.31 (2023-02-12)
- [Feature] Allow for adding partitions via `Admin#create_partitions` API.
- [Fix] Do not ignore admin errors upon invalid configuration (#1254)
- [Fix] Topic name validation (#1300) - CandyFet
- [Enhancement] Increase the `max_wait_timeout` on admin operations to five minutes to make sure no timeout on heavily loaded clusters.
- [Maintenance] Require `karafka-core` >= `2.0.11` and switch to shared RSpec locator.
- [Maintenance] Require `karafka-rdkafka` >= `0.12.1`

## 2.0.30 (2023-01-31)
- [Enhancement] Alias `--consumer-groups` with `--include-consumer-groups`
- [Enhancement] Alias `--subscription-groups` with `--include-subscription-groups`
- [Enhancement] Alias `--topics` with `--include-topics`
- [Enhancement] Introduce `--exclude-consumer-groups` for ability to exclude certain consumer groups from running
- [Enhancement] Introduce `--exclude-subscription-groups` for ability to exclude certain subscription groups from running
- [Enhancement] Introduce `--exclude-topics` for ability to exclude certain topics from running

## 2.0.29 (2023-01-30)
- [Enhancement] Make sure, that the `Karafka#producer` instance has the `LoggerListener` enabled in the install template, so Karafka by default prints both consumer and producer info.
- [Enhancement] Extract the code loading capabilities of Karafka console from the executable, so web can use it to provide CLI commands.
- [Fix] Fix for: running karafka console results in NameError with Rails (#1280)
- [Fix] Make sure, that the `caller` for async errors is being published.
- [Change] Make sure that WaterDrop `2.4.10` or higher is used with this release to support Web-UI.

## 2.0.28 (2023-01-25)
- **[Feature]** Provide the ability to use Dead Letter Queue with Virtual Partitions.
- [Enhancement] Collapse Virtual Partitions upon retryable error to a single partition. This allows dead letter queue to operate and mitigate issues arising from work virtualization. This removes uncertainties upon errors that can be retried and processed. Affects given topic partition virtualization only for multi-topic and multi-partition parallelization. It also minimizes potential "flickering" where given data set has potentially many corrupted messages. The collapse will last until all the messages from the collective corrupted batch are processed. After that, virtualization will resume.
- [Enhancement] Introduce `#collapsed?` consumer method available for consumers using Virtual Partitions.
- [Enhancement] Allow for customization of DLQ dispatched message details in Pro (#1266) via the `#enhance_dlq_message` consumer method.
- [Enhancement] Include `original_consumer_group` in the DLQ dispatched messages in Pro.
- [Enhancement] Use Karafka `client_id` as kafka `client.id` value by default

### Upgrade Notes

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
- [Enhancement] Early terminate on `read_topic` when reaching the last offset available on the request time.
- [Enhancement] Introduce a `quiet` state that indicates that Karafka is not only moving to quiet mode but actually that it reached it and no work will happen anymore in any of the consumer groups.
- [Enhancement] Use Karafka defined routes topics when possible for `read_topic` admin API.
- [Enhancement] Introduce `client.pause` and `client.resume` instrumentation hooks for tracking client topic partition pausing and resuming. This is alongside of `consumer.consuming.pause` that can be used to track both manual and automatic pausing with more granular consumer related details. The `client.*` should be used for low level tracking.
- [Enhancement] Replace `LoggerListener` pause notification with one based on `client.pause` instead of `consumer.consuming.pause`.
- [Enhancement] Expand `LoggerListener` with `client.resume` notification.
- [Enhancement] Replace random anonymous subscription groups ids with stable once.
- [Enhancement] Add `consumer.consume`, `consumer.revoke` and `consumer.shutting_down` notification events and move the revocation logic calling to strategies.
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
- [Enhancement] Add instrumentation upon `#pause`.
- [Enhancement] Add instrumentation upon retries.
- [Enhancement] Assign `#id` to consumers similar to other entities for ease of debugging.
- [Enhancement] Add retries and pausing to the default `LoggerListener`.
- [Enhancement] Introduce a new final `terminated` state that will kick in prior to exit but after all the instrumentation and other things are done.
- [Enhancement] Ensure that state transitions are thread-safe and ensure state transitions can occur in one direction.
- [Enhancement] Optimize status methods proxying to `Karafka::App`.
- [Enhancement] Allow for easier state usage by introducing explicit `#to_s` for reporting.
- [Enhancement] Change auto-generated id from `SecureRandom#uuid` to `SecureRandom#hex(6)`
- [Enhancement] Emit statistic every 5 seconds by default.
- [Enhancement] Introduce general messages parser that can be swapped when needed.
- [Fix] Do not trigger code reloading when `consumer_persistence` is enabled.
- [Fix] Shutdown producer after all the consumer components are down and the status is stopped. This will ensure, that any instrumentation related Kafka messaging can still operate.

### Upgrade Notes

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
- [Enhancement] Provide `Admin#read_topic` API to get topic data without subscribing.
- [Enhancement] Upon an end user `#pause`, do not commit the offset in automatic offset management mode. This will prevent from a scenario where pause is needed but during it a rebalance occurs and a different assigned process starts not from the pause location but from the automatic offset that may be different. This still allows for using the `#mark_as_consumed`.
- [Fix] Fix a scenario where manual `#pause` would be overwritten by a resume initiated by the strategy.
- [Fix] Fix a scenario where manual `#pause` in LRJ would cause infinite pause.

## 2.0.22 (2022-12-02)
- [Enhancement] Load Pro components upon Karafka require so they can be altered prior to setup.
- [Enhancement] Do not run LRJ jobs that were added to the jobs queue but were revoked meanwhile.
- [Enhancement] Allow running particular named subscription groups similar to consumer groups.
- [Enhancement] Allow running particular topics similar to consumer groups.
- [Enhancement] Raise configuration error when trying to run Karafka with options leading to no subscriptions.
- [Fix] Fix `karafka info` subscription groups count reporting as it was misleading.
- [Fix] Allow for defining subscription groups with symbols similar to consumer groups and topics to align the API.
- [Fix] Do not allow for an explicit `nil` as a `subscription_group` block argument.
- [Fix] Fix instability in subscription groups static members ids when using `--consumer_groups` CLI flag.
- [Fix] Fix a case in routing, where anonymous subscription group could not be used inside of a consumer group.
- [Fix] Fix a case where shutdown prior to listeners build would crash the server initialization.
- [Fix] Duplicated logs in development environment for Rails when logger set to `$stdout`.

## 20.0.21 (2022-11-25)
- [Enhancement] Make revocation jobs for LRJ topics non-blocking to prevent blocking polling when someone uses non-revocation aware LRJ jobs and revocation happens.

## 2.0.20 (2022-11-24)
- [Enhancement] Support `group.instance.id` assignment (static group membership) for a case where a single consumer group has multiple subscription groups (#1173).

## 2.0.19 (2022-11-20)
- **[Feature]** Provide ability to skip failing messages without dispatching them to an alternative topic (DLQ).
- [Enhancement] Improve the integration with Ruby on Rails by preventing double-require of components.
- [Enhancement] Improve stability of the shutdown process upon critical errors.
- [Enhancement] Improve stability of the integrations spec suite.
- [Fix] Fix an issue where upon fast startup of multiple subscription groups from the same consumer group, a ghost queue would be created due to problems in `Concurrent::Hash`.

## 2.0.18 (2022-11-18)
- **[Feature]** Support quiet mode via `TSTP` signal. When used, Karafka will finish processing current messages, run `shutdown` jobs, and switch to a quiet mode where no new work is being accepted. At the same time, it will keep the consumer group quiet, and thus no rebalance will be triggered. This can be particularly useful during deployments.
- [Enhancement] Trigger `#revoked` for jobs in case revocation would happen during shutdown when jobs are still running. This should ensure, we get a notion of revocation for Pro LRJ jobs even when revocation happening upon shutdown (#1150).
- [Enhancement] Stabilize the shutdown procedure for consumer groups with many subscription groups that have non-aligned processing cost per batch.
- [Enhancement] Remove double loading of Karafka via Rails railtie.
- [Fix] Fix invalid class references in YARD docs.
- [Fix] prevent parallel closing of many clients.
- [Fix] fix a case where information about revocation for a combination of LRJ + VP would not be dispatched until all VP work is done.

## 2.0.17 (2022-11-10)
- [Fix] Few typos around DLQ and Pro DLQ Dispatch original metadata naming.
- [Fix] Narrow the components lookup to the appropriate scope (#1114)

### Upgrade Notes

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
- [Enhancement] Align attributes available in the instrumentation bus for listener related events.
- [Enhancement] Include consumer group id in consumption related events (#1093)
- [Enhancement] Delegate pro components loading to Zeitwerk
- [Enhancement] Include `Datadog::LoggerListener` for tracking logger data with DataDog (@bruno-b-martins)
- [Enhancement] Include `seek_offset` in the `consumer.consume.error` event payload (#1113)
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

### Upgrade Notes

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
