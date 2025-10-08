# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When using a custom scheduler we should by no means use consume scheduling API for idle jobs

become_pro!

class Scheduler < Karafka::Pro::Processing::Schedulers::Base
  def schedule_consumption(jobs_array)
    jobs_array.each do |job|
      # This API is only available in the consume jobs so idle jobs would crash
      job.messages.size
      @queue << job
    end
  end
end

setup_karafka do |config|
  config.concurrency = 10
  config.max_messages = 10
  config.internal.processing.scheduler_class = Scheduler
end

class Consumer < Karafka::BaseConsumer
  def consume; end
end

class FullRemoval < Karafka::Pro::Processing::Filters::Base
  attr_reader :cursor

  def apply!(messages)
    @applied = false
    @cursor = messages.first

    DT[0] << true

    messages.clear
  end

  def action
    :seek
  end

  def applied?
    true
  end

  def timeout
    0
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    filter(->(*) { FullRemoval.new })
  end
end

# No ned to do anything, this will crash if the consume scheduler flow gets idle job
start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(5))

  DT[0].size >= 5
end
