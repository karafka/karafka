# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Example scheduler that evenly distributes work coming from multiple topics. It allocates workers
# evenly so each topic has resources. When rebalance occurs, the distribution ratio will change and
# will be updated

become_pro!

class FairScheduler < Karafka::Pro::Processing::Schedulers::Base
  def initialize(queue)
    super
    @buffer = []
    @scheduled = []
  end

  def schedule_consumption(jobs_array)
    # Always lock for the sake of code simplicity
    jobs_array.each do |job|
      @buffer << job
      queue.lock(job)
    end

    manage
  end

  def manage
    # Clear previously scheduled job that have finished
    # We use it to track topics work that is already running
    @scheduled.delete_if(&:finished?)

    # If all threads are already running there is no point in more assignments
    # This could be skipped ofc as more would just go to the queue but it demonstrates that
    # we can also use queue statistics in schedulers
    return if queue.statistics[:busy] >= concurrency

    @buffer.delete_if do |job|
      # If we already have enough work of this topic, we do nothing
      next if active_per_topic(job) >= workers_per_topic

      # If we have space for it, we allow it to operate
      @scheduled << job
      queue.unlock(job)
      queue << job

      true
    end
  end

  def clear(group_id)
    @buffer.delete_if { |job| job.group_id == group_id }
  end

  private

  def concurrency
    Karafka::App.config.concurrency
  end

  # Count already scheduled and running jobs for topic of the job we may schedule
  def active_per_topic(job)
    @scheduled.count { |s_job| s_job.executor.topic == job.executor.topic }
  end

  # Get number of topics assigned
  # If there are more topics than workers, we assume 1
  def workers_per_topic
    (concurrency / Karafka::App.assignments.size.to_f).ceil
  end
end

setup_karafka do |config|
  config.concurrency = 10
  config.max_messages = 50
  config.internal.processing.scheduler_class = FairScheduler
end

class Consumer < Karafka::BaseConsumer
  def consume
    # There may be a case where both assignments are reached not exactly at the same moment.
    # This would mess the assertions, so we skip it as it is not the primary case we want to
    # check here
    return unless Karafka::App.assignments.size >= 2

    messages.each { DT[:total] << true }

    start = Time.now.to_f
    sleep(rand)
    stop = Time.now.to_f

    DT[:runs] << [topic.name, (start..stop)]
  end
end

draw_routes do
  subscription_group :a do
    topic DT.topics[0] do
      consumer Consumer
      virtual_partitions(
        partitioner: ->(_) { rand(10) }
      )
    end
  end

  subscription_group :b do
    topic DT.topics[1] do
      consumer Consumer
      virtual_partitions(
        partitioner: ->(_) { rand(10) }
      )
    end
  end
end

produce_many(DT.topics[0], DT.uuids(100))
produce_many(DT.topics[1], DT.uuids(100))

start_karafka_and_wait_until do
  DT[:total].size >= 200
end

# Never we should have mor jobs from a given topic running concurrently than 5
DT[:runs].group_by(&:first).each_value do |group|
  times = group.map(&:last)

  times.each do |range|
    assert times.count { |time| time.cover?(range.begin) } <= 5
  end
end
