# frozen_string_literal: true

# We use the same initialization and control flow for benchmarks as for specs, that's why we
# require it that way

require_relative 'integrations_helper'

# We set stdout to sync so all the messages from the benchmarks are visible immediately
$stdout.sync = true

# Sets up karafka with benchmark expected defaults (low logging, etc)
def setup_karafka
  Karafka::App.setup do |config|
    # Use some decent defaults
    caller_id = [caller_locations(1..1).first.path.split('/').last, SecureRandom.uuid].join('-')

    config.kafka = { 'bootstrap.servers': '127.0.0.1:9092' }
    config.client_id = caller_id
    config.pause_timeout = 1
    config.pause_max_timeout = 1
    config.pause_with_exponential_backoff = false
    config.logger = ::Logger.new($stdout)
    config.logger.level = ::Logger::ERROR

    # Allows to overwrite any option we're interested in
    yield(config) if block_given?
  end

  Karafka.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)
end

# Alias for drawing routes in the same way across benchmarks
#
# @param topic [String] topic name
# @param consumer_class [Class] consumer class
def draw_routes(topic, consumer_class = Consumer)
  Karafka::App.routes.draw do
    consumer_group DT.consumer_group do
      topic topic do
        max_messages 1_000
        max_wait_time 1_000
        consumer consumer_class
        manual_offset_management true
      end

      yield(self) if block_given?
    end
  end
end

# @return [String] valid pro license token that we use in the integration tests
def pro_license_token
  ENV.fetch('KARAFKA_PRO_LICENSE_TOKEN')
end

# Time extensions
class Time
  class << self
    # @return [Float] monotonic time now
    def monotonic
      ::Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end

# Process extensions
module Process
  class << self
    # Runs a fork with given block of code and runs it in a loop as long as the parent process is
    # alive. When parent process dies, it finishes as well
    def fork_supervised
      parent_pid = Process.pid

      fork do
        yield while Process.alive?(parent_pid)
      end
    end

    # @param pid [Integer] pid of a process we want to check
    # @return [Boolean] true if process with give pid exists, false otherwise
    def alive?(pid)
      getpgid(pid)
      true
    rescue Errno::ESRCH
      false
    end
  end
end

# A simple time tracker with iterations to simplify time taken aggregation
class Tracker
  class << self
    # Runs what we are interested in, collects results and prints stats
    # @param iterations [Integer]
    # @param messages_count [Integer, nil] how many messages did we process overall or nil if
    #   the benchmark is not per message data related
    # @param block [Proc] code we want to run in iterations
    def run(messages_count: nil, iterations: 10, &block)
      instance = new(iterations: iterations, messages_count: messages_count)

      instance.iterate { block.call }

      instance.report
    end
  end

  # @param iterations [Integer]
  # @param messages_count [Integer] how many messages did we process overall
  def initialize(iterations:, messages_count:)
    @iterations = iterations
    @messages_count = messages_count
    @times = []
  end

  # Runs iterations of the code we want and prints the iteration number and stores the end result
  #   internally as we expect it to be time taken
  def iterate
    @iterations.times do |i|
      puts "Running iteration: #{i + 1}"

      @times << yield
    end
  end

  # Prints summary of measurements
  def report
    puts "Time taken: #{average}"
    puts "Messages per second: #{@messages_count / average}" if @messages_count
  end

  private

  # @return [Float] average time taken
  def average
    @times.sum / @times.size
  end
end
