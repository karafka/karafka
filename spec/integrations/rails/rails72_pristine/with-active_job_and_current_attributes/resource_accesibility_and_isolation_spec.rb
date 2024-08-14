# frozen_string_literal: true

# This spec validates, that while we run work in parallel in multiple threads, the context of
# `Current` never leaks in between them and that `Current` is always current to the local
# thread in which given consumer operates

ENV['KARAFKA_CLI'] = 'true'

Bundler.require(:default)

require 'action_controller'
require 'tempfile'
require 'active_job'
require 'active_job/karafka'
require 'karafka/active_job/current_attributes'

class ExampleApp < Rails::Application
  config.eager_load = 'test'
end

dummy_boot_file = "#{Tempfile.new.path}.rb"
FileUtils.touch(dummy_boot_file)
ENV['KARAFKA_BOOT_FILE'] = dummy_boot_file

ExampleApp.initialize!

setup_karafka do |config|
  config.concurrency = 20
  config.max_messages = 100
  config.max_wait_time = 500
  # Fetch one message a a time from partition (or something like that)
  # to make sure we have a chance to operate in parallel
  config.kafka[:'fetch.message.max.bytes'] = 1
end

class Current < ActiveSupport::CurrentAttributes
  attribute :user
end

class ContextAwareOperation
  class << self
    def call
      start = Time.now.to_f

      users = Set.new

      100.times do
        users << Current.user
        sleep(rand / 100.0)
      end

      stop = Time.now.to_f

      # Range of time where we should get only one users value out of Current as long as it holds
      # appropriate thread context
      DT[:operations] << [(start..stop), users]
    end
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    Current.user = SecureRandom.uuid
    ContextAwareOperation.call
    DT[:messages] << messages.count
    DT[:partitions] << messages.metadata.partition
  end
end

Karafka::ActiveJob::CurrentAttributes.persist(Current)

draw_routes do
  topic DT.topic do
    # Run many operations in many partitions to stress out
    # concurrency
    config(partitions: 20)
    consumer Consumer
  end
end

def done?
  DT[:messages].sum >= 1000 && DT[:partitions].uniq.count >= 10
end

Thread.new do
  until done?
    20.times do |partition|
      produce_many(DT.topic, DT.uuids(10), partition: partition)
    end

    sleep(rand / 10.0)
  end
end

start_karafka_and_wait_until do
  done?
end

# Make sure that each operation has always only one `Current` value
# This shows that the context is not leaking
DT[:operations].each do |operation|
  assert_equal 1, operation[1].size
end

# Make sure, that there were some operations that were overlapping in their execution time.
# This allows us to ensure that indeed we did run independent work units in parallel
# Not all ranges need to overlap with each other but some should
def ranges_overlap?(range_a, range_b)
  range_b.begin <= range_a.end && range_a.begin <= range_b.end
end

ranges = DT[:operations].map(&:first)
overlaping = false

ranges.each do |range|
  overlaping = true if ranges.any? do |other|
    other != range && ranges_overlap?(other, range)
  end
end

assert overlaping
