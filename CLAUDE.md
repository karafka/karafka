# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Karafka is a Ruby and Rails multi-threaded Kafka processing framework built around librdkafka. It provides a comprehensive solution for consuming and processing Kafka messages with support for complex message processing patterns, dead letter queues, virtual partitions, and extensive monitoring capabilities.

## Key Architecture Components

### Core Framework Structure
- **Karafka::App**: Main application class that manages configuration, routing, and lifecycle
- **Karafka::BaseConsumer**: Base class for all message consumers with lifecycle hooks
- **Karafka::Routing::Builder**: DSL for defining consumer groups, topics, and subscription groups
- **Karafka::Processing::Coordinator**: Manages message processing coordination and state
- **Karafka::Connection::Client**: Wraps librdkafka client for Kafka operations

### Message Processing Flow
1. Messages are consumed through `Connection::Client` (librdkafka wrapper)
2. `Processing::Coordinator` manages processing state and error handling
3. `BaseConsumer` subclasses implement business logic in `#consume` method
4. Messages are represented by `Messages::Message` and `Messages::Messages` collections
5. Offset management and pausing/seeking is handled transparently

### Pro Components
The framework includes Pro components under `lib/karafka/pro/` that provide advanced features:
- Virtual partitions for parallel processing within single partition
- Enhanced Dead Letter Queue functionality  
- Scheduled messages and recurring tasks
- Advanced filtering and throttling
- Long-running job support

## Development Commands

### Testing
- `bundle exec rspec` - Run all unit tests
- `bundle exec rspec spec/integrations/` - Run integration tests  
- `SPECS_TYPE=pro bundle exec rspec` - Run pro component tests

### Gem Development
- `bundle exec rake build` - Build the gem
- `bundle exec rake install` - Build and install locally
- `bundle exec rake release` - Release new version (requires credentials)

### Code Quality
- Uses SimpleCov for test coverage (minimum 93.6% for pro specs)
- Integrates with Coditsu for automated code quality checks
- Strict Ruby warnings enabled in test environment

## Testing Architecture

### Test Structure
- `spec/lib/` - Unit tests for individual components
- `spec/integrations/` - Integration tests simulating real Kafka scenarios
- `spec/support/` - Test helpers and factories
- Uses FactoryBot for test data creation

### Key Test Patterns
- Tests are organized by feature area (consumption, routing, instrumentation, etc.)
- Integration tests validate end-to-end message processing flows
- Pro features are tested separately with `SPECS_TYPE=pro`
- Tests use real Kafka instance (requires Kafka running on 127.0.0.1:9092)

## Configuration and Setup

### Application Configuration
- Configuration done through `Karafka::App.setup` block
- Routes defined using `Karafka::App.routes.draw` DSL
- Supports both simple topic-based and complex consumer group configurations
- Environment-specific configuration through `Karafka.env`

### CLI Commands
The framework provides extensive CLI through `bin/karafka`:
- `karafka server` - Start message processing
- `karafka console` - Interactive console
- `karafka install` - Bootstrap new application
- `karafka topics` - Topic management commands
- `karafka info` - Display configuration info
- `karafka swarm` - Multi-process management

## Important Development Notes

### Code Organization
- Core components in `lib/karafka/`
- Pro components in `lib/karafka/pro/` (commercial license)
- CLI commands in `lib/karafka/cli/`
- Processing strategies in `lib/karafka/processing/strategies/`

### Consumer Development
- All consumers inherit from `Karafka::BaseConsumer`
- Implement `#consume` method for message processing
- Use lifecycle hooks: `#initialized`, `#eofed`, `#revoked`, `#shutdown`
- Access messages via `#messages`, producer via `#producer`
- Error handling through instrumentation events

### Testing Requirements
- Tests must not assume specific Kafka setup beyond basic broker
- Use provided test helpers in `spec/support/`
- Integration tests should clean up topics/consumer groups
- Pro features require valid license token for testing

### Instrumentation
- Comprehensive instrumentation through `Karafka.monitor`
- Events cover entire message lifecycle and error conditions
- Custom listeners can be added for monitoring/logging
- Built-in support for AppSignal and DataDog integration
