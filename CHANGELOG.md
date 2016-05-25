# Karafka framework changelog

## 0.4.1-head
- #61 - Autodiscover Kafka brokers based on Zookeeper data
- #63 - Graceful shutdown with current offset state during data processing
- #65 - Example of NewRelic monitor is outdated
- #71 - Setup should be executed after user code is loaded
- Gem dump x2
- Rubocop remarks
- worker_timeout config option has been removed. It now needs to be defined manually by the framework user because WorkerGlass::Timeout can be disabled and we cannot use Karafka settings on a class level to initialize user code stuff
- Moved setup logic under setup/Setup namespace
- Better defaults handling
- #75 - Kafka and Zookeeper options as a hash
- #82 - Karafka autodiscovery fails upon caching of configs
- #81 - Switch config management to dry configurable
- Version fix

## 0.4.0
- Added WaterDrop gem with default configuration
- Refactoring of config logic to simplify adding new dependencies that need to be configured based on #setup data
- Gem dump
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
- Gem dump
- Fixed #32 - now when using custom workers that does not inherit from Karafka::BaseWorker perform method is not required. Using custom workers means that the logic that would normally lie under #perform, needs to be executed directly from the worker.
- Fixed #31 - Technically didn't fix because this is how Sidekiq is meant to work, but provided possibility to assign custom interchangers that allow to bypass JSON encoding issues by converting data that goes to Redis to a required format (and parsing it back when it is fetched)
- Added full parameters lazy load - content is no longer loaded during #perform_async if params are not used in before_enqueue
- No more namespaces for Redis by default (use separate DBs)

## 0.1.21
- Sidekiq 4.0.1 dump
- Gem dump
- Added direct celluloid requirement to Karafka (removed from Sidekiq)

## 0.1.19
- Internal call - schedule naming change
- Enqueue to perform_async naming in controller to follow Sidekiqs naming convention
- Gem dump

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
- Gem dump

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

