# frozen_string_literal: true

# This pristine spec simulates the real-world scenario from GitHub issue #2363
# where routing configuration is split across multiple files, each defining
# topics in the same consumer group.
#
# Directory structure:
# - routes/users_routes.rb  - defines topics in a shared consumer group
# - routes/orders_routes.rb - reopens the same consumer group with more topics
# - consumers/              - consumer implementations
#
# Expected behavior: All topics should accumulate in the same consumer group,
# allowing for modular routing configuration.

require 'karafka'
require 'singleton'
require 'securerandom'

# Load DataCollector for DT support unless already defined
unless defined?(DT)
  class DataCollector
    include Singleton

    attr_reader :topics, :consumer_groups

    def self.topics
      instance.topics
    end

    def self.consumer_groups
      instance.consumer_groups
    end

    def initialize
      @topics = Array.new(100) { "it-#{SecureRandom.hex(8)}" }
      @consumer_groups = @topics
    end
  end

  DT = DataCollector
end

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
consumer_group = Karafka::App.routes.find { |cg| cg.name == DT.consumer_groups[0] }

raise 'Consumer group should exist' if consumer_group.nil?

# Should have all 4 topics from both route files
expected_topics = [DT.topics[0], DT.topics[1], DT.topics[2], DT.topics[3]].sort
actual_topics = consumer_group.topics.map(&:name).sort

unless actual_topics == expected_topics
  raise "Expected topics #{expected_topics.inspect}, got #{actual_topics.inspect}"
end

# Verify consumers are correctly assigned
topic0 = consumer_group.topics.to_a.find { |t| t.name == DT.topics[0] }
topic1 = consumer_group.topics.to_a.find { |t| t.name == DT.topics[1] }
topic2 = consumer_group.topics.to_a.find { |t| t.name == DT.topics[2] }
topic3 = consumer_group.topics.to_a.find { |t| t.name == DT.topics[3] }

raise 'topic0 should have UsersConsumer' unless topic0.consumer == UsersConsumer
raise 'topic1 should have UsersConsumer' unless topic1.consumer == UsersConsumer
raise 'topic2 should have OrdersConsumer' unless topic2.consumer == OrdersConsumer
raise 'topic3 should have OrdersConsumer' unless topic3.consumer == OrdersConsumer

# Verify all topics have correct initial_offset
[topic0, topic1, topic2, topic3].each do |topic|
  next if topic.initial_offset == 'earliest'

  raise(
    "#{topic.name} should have initial_offset 'earliest', got #{topic.initial_offset.inspect}"
  )
end
