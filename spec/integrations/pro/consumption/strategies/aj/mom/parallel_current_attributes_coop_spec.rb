# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should correctly assign and manage the current attributes in multiple threads

setup_karafka do |config|
  config.concurrency = 10
end

setup_active_job

require 'karafka/active_job/current_attributes'

draw_routes do
  active_job_topic DT.topic do
    config(partitions: 50)
  end
end

class CurrentA < ActiveSupport::CurrentAttributes
  attribute :a
end

class CurrentB < ActiveSupport::CurrentAttributes
  attribute :b
end

Karafka::ActiveJob::CurrentAttributes.persist(CurrentA)
Karafka::ActiveJob::CurrentAttributes.persist(CurrentB)

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    sleep((rand / 100))
    DT[0] << [value, CurrentA.a, CurrentB.b]
  end
end

1000.times do |value|
  CurrentA.a = value
  CurrentB.b = value + 1
  Job.perform_later(value)
end

start_karafka_and_wait_until do
  DT[0].size >= 1000
end

DT[0].each do |result|
  assert_equal result[0], result[1]
  assert_equal result[0] + 1, result[2]
end
