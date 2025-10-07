# frozen_string_literal: true

# This pristine spec simulates the real-world scenario from GitHub issue #2363
# where routing configuration is split across multiple files, each defining
# topics in the same consumer group.
#
# Directory structure:
# - routes/users_routes.rb  - defines 'users.*' topics in 'main_app' group
# - routes/orders_routes.rb - reopens 'main_app' group with 'orders.*' topics
# - consumers/              - consumer implementations
#
# Expected behavior: All topics should accumulate in the same 'main_app'
# consumer group, allowing for modular routing configuration.

require 'karafka'

# Load consumer classes
current_dir = __dir__
require File.join(current_dir, 'consumers', 'users_consumer')
require File.join(current_dir, 'consumers', 'orders_consumer')

# Setup Karafka with basic configuration
Karafka::App.setup do |config|
  config.kafka = { 'bootstrap.servers': '127.0.0.1:9092' }
  config.client_id = 'pristine_multi_file_test'
  config.consumer_persistence = false
end

# Load routing files - each file will reopen the same consumer group
# This simulates splitting routing config across domain-specific files
require File.join(current_dir, 'routes', 'users_routes')
require File.join(current_dir, 'routes', 'orders_routes')

# Verify that consumer group reopening worked correctly
consumer_group = Karafka::App.routes.find { |cg| cg.name == 'main_app' }

raise 'Consumer group "main_app" should exist' if consumer_group.nil?

# Should have all 4 topics from both route files
expected_topics = %w[orders.completed orders.placed users.created users.updated]
actual_topics = consumer_group.topics.map(&:name).sort

unless actual_topics == expected_topics
  raise "Expected topics #{expected_topics.inspect}, got #{actual_topics.inspect}"
end

# Verify consumers are correctly assigned
users_created = consumer_group.topics.to_a.find { |t| t.name == 'users.created' }
users_updated = consumer_group.topics.to_a.find { |t| t.name == 'users.updated' }
orders_placed = consumer_group.topics.to_a.find { |t| t.name == 'orders.placed' }
orders_completed = consumer_group.topics.to_a.find { |t| t.name == 'orders.completed' }

raise 'users.created should have UsersConsumer' unless users_created.consumer == UsersConsumer
raise 'users.updated should have UsersConsumer' unless users_updated.consumer == UsersConsumer
raise 'orders.placed should have OrdersConsumer' unless orders_placed.consumer == OrdersConsumer

unless orders_completed.consumer == OrdersConsumer
  raise 'orders.completed should have OrdersConsumer'
end

# Verify all topics have correct initial_offset
[users_created, users_updated, orders_placed, orders_completed].each do |topic|
  unless topic.initial_offset == 'earliest'
    raise(
      "#{topic.name} should have initial_offset 'earliest', got #{topic.initial_offset.inspect}"
    )
  end
end
