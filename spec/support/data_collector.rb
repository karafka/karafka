# frozen_string_literal: true

# A helper class that we use to run integration specs and collect the results outside of the
# Karafka framework
#
# @note It is a singleton
class DataCollector
  include Singleton

  attr_reader :topic, :topics, :data

  class << self
    # @return [String] topic we want to use in the context of the current spec
    def topic
      instance.topic
    end

    # @return [ConcurrentHash] structure for aggregating data
    def data
      instance.data
    end

    # Clears the collector
    def reset
      instance.reset
    end
  end

  # Creates a collector
  def initialize
    @topics = Array.new(100) { |i| "t-#{i}-#{Time.now.to_f}" }
    @data = Concurrent::Hash.new { |hash, key| hash[key] = Concurrent::Array.new }
  end

  def topic
    topics.first
  end

  # Clears the collector
  def reset
    @topics = Array.new(100) { |i| "t-#{i}-#{Time.now.to_f}" }
    @data = Concurrent::Hash.clear
  end
end
