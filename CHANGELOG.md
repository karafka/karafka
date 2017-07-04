# Karafka framework changelog

## Unreleased
- #150 - Add support for start_from_beginning on a per topic basis
- Got rid of PolishGeeksDevTools (will be replaced with Coditsu soon)
- Gem bump (dry-stuff and other gems)

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

