# Karafka framework changelog

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

## 1.2.5
- #354 - Expose consumer heartbeat
- #373 - Async producer not working properly with responders

## 1.2.4
- #332 - Fetcher for max queue size

## 1.2.3
- #313 - support PLAINTEXT and SSL for scheme
- #320 - Pausing indefinetely with nil pause timeout doesn't work
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
- #96 - Karafka server - possiblity to run it only for a certain topics
- ~~karafka worker cli option is removed (please use sidekiq directly)~~ - restored, bad idea
- (optional) pausing upon processing failures ```pause_timeout```
- Karafka console main process no longer intercepts irb errors
- Wiki updates
- #204 - Long running controllers
- Better internal API to handle multiple usage cases using ```Karafka::Controllers::Includer```
- #207 - Rename before_enqueued to after_received
- #147 - Deattach Karafka from Sidekiq by extracting Sidekiq backend

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
- #97 - Buffer responders single topics before send (prevalidation)
- Better control over consumer thanks to additional config options
- #111 - Dynamic worker assignment based on the income params
- Long shutdown time fix

## 0.5.0
- Removed Zookeeper totally as dependency
- Better group and partition rebalancing
- Automatic thread management (no need for tunning) - each topic is a separate actor/thread
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
- Responders support for handling better responses pipelining and better responses flow description and design (see README for more details)
- Gem bump
- Readme updates
- karafka flow CLI command for printing the application flow
- Some internal refactorings

## 0.4.2
- #87 - Reconsume mode with crone for better Rails/Rack integration
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
- #61 - Autodiscover Kafka brokers based on Zookeeper data
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
- Standarized logging format for all logs

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
- Enqueue to perform_async naming in controller to follow Sidekiqs naming convention
- Gem bump

## 0.1.18
- Changed Redis configuration options into a single hash that is directly passed to Redis setup for Sidekiq
- Added config.ru to provide a Sidekiq web UI (see README for more details)

## 0.1.17
- Changed Karafka::Connection::Cluster tp Karafka::Connection::ActorCluster to distinguish between a single thread actor cluster for multiple topic connection and a future feature that will allow process clusterization.
- Add an ability to use user-defined parsers for a messages
- Lazy load params for before callbacks
- Automatic loading/initializng all workers classes during startup (so Sidekiq won't fail with unknown workers exception)
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
- Droped local env suppot in favour of [Envlogic](https://github.com/karafka/envlogic) - no changes in API

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
- Raketasks updates
- Rake installation task
- Changelog file added

## 0.1.0
- Initial framework code
