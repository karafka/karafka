# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When using a scheduler that would allow only a single thread, despite having more, we should
# never use them in any way

become_pro!

class OneThreadScheduler < ::Karafka::Pro::Processing::Schedulers::Base
  def initialize(queue)
    super
    @jobs_buffer = []
  end

  def schedule_consumption(jobs_array)
    jobs_array.each do |job|
      @jobs_buffer << job
      @queue.lock(job)
    end

    internal_manage
  end

  def manage
    internal_manage
  end

  def clear(group_id)
    @jobs_buffer.delete_if { |job| job.group_id == group_id }
  end

  private

  def internal_manage
    @jobs_buffer.delete_if do |job|
      next unless @queue.statistics[:busy].zero?

      @queue << job
      @queue.unlock(job)

      true
    end
  end
end

setup_karafka do |config|
  config.concurrency = 10
  config.max_messages = 50
  config.internal.processing.scheduler_class = OneThreadScheduler
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { DT[:total] << true }

    start = Time.now.to_f
    sleep(rand)
    stop = Time.now.to_f
    DT[:runs] << (start..stop)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(_) { rand(10) }
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:total].size >= 100
end

DT[:runs].each do |run1|
  DT[:runs].each do |run2|
    next if run1 == run2

    assert_no_overlap(run1, run2)
  end
end
