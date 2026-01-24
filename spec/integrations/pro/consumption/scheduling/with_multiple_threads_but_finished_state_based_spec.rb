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

# We should be able to build a scheduler that can base further job scheduling based on the other
# jobs execution flow.
#
# While this scheduler is not explicitely single-threaded, it waits on previous job to finish
# before enqueuing more. This "makes it" single threaded.

become_pro!

class WorkBasedScheduler < Karafka::Pro::Processing::Schedulers::Base
  def initialize(queue)
    super
    @jobs_buffer = []
    @in_progress = nil
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
      # If there is one running job, don't schedule more
      next if @in_progress && !@in_progress.finished?

      @in_progress = job
      @queue << job
      @queue.unlock(job)

      true
    end
  end
end

setup_karafka do |config|
  config.concurrency = 10
  config.max_messages = 50
  config.internal.processing.scheduler_class = WorkBasedScheduler
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

produce_many(DT.topic, DT.uuids(50))

start_karafka_and_wait_until do
  DT[:total].size >= 50
end

DT[:runs].each do |run1|
  DT[:runs].each do |run2|
    next if run1 == run2

    assert_no_overlap(run1, run2)
  end
end
