# frozen_string_literal: true

# A helper class that we use to run integration specs and collect the results outside of the
# Karafka framework
#
# @note It is a singleton
class DataCollector
  include Singleton

  attr_reader :topics, :consumer_groups, :data

  class << self
    # @return [String] topic we want to use in the context of the current spec
    def topic
      instance.topic
    end

    # @return [Array<String>] available topics
    def topics
      instance.topics
    end

    # @return [ConcurrentHash] structure for aggregating data
    def data
      instance.data
    end

    # @return [String] first consumer group
    def consumer_group
      instance.consumer_group
    end

    # @return [Array<String>] available consumer groups
    def consumer_groups
      instance.consumer_groups
    end

    # Alias to the data key (used frequently)
    #
    # @param key [Object] key for the data access
    # @return [Object] anything under given key in the data
    def [](key)
      data[key]
    end

    # Alias to the data assignment
    #
    # @param key [Object] anything we want to have as a key
    # @param value [Object] anything we want to store
    def []=(key, value)
      data[key] = value
    end
  end

  # Creates a collector
  def initialize
    @topics = Concurrent::Array.new(100) { SecureRandom.uuid }
    @consumer_groups = @topics
    @data = Concurrent::Hash.new { |hash, key| hash[key] = Concurrent::Array.new }
  end

  # @return [String] first topic name
  def topic
    topics.first
  end

  # @return [String] first consumer group
  def consumer_group
    topics.first
  end
end
