# Karafka framework changelog

## 2.0.0-beta4 (Unreleased)
- Rename job internal api methods from `#prepare` to `#before_call` and from `#teardown` to `#after_call` to abstract away jobs execution from any type of executors and consumers logic

## 2.0.0-beta3 (2022-06-14)
- Jobs building responsibility extracted out of the listener code base.
- Fix a case where specs supervisor would try to kill no longer running process (#868)
- Fix an instable integration spec that could misbehave under load
- Commit offsets prior to pausing partitions to ensure that the latest offset is always committed
- Fix a case where consecutive CTRL+C (non-stop) would case an exception during forced shutdown
- Add missing `consumer.prepared.error` into `LoggerListener`
- Delegate partition resuming from the consumers to listeners threads.
- Add support for Long Running Jobs (LRJ) for ActiveJob [PRO]
- Add support for Long Running Jobs for consumers [PRO]
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
