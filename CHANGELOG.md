# Karafka framework changelog

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
