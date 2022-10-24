# frozen_string_literal: true

# When we have an vp AJ jobs in few batches, upon shutdown, not finished work should not be
# committed, but the previous offset should. Only fully finished AJ VP batches should be considered
# finished.

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 2
  config.max_messages = 2
end

setup_active_job

draw_routes do
  consumer_group DT.consumer_group do
    active_job_topic DT.topic do
      virtual_partitions(
        partitioner: ->(_) { (0..4).to_a.sample }
      )
    end
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    sleep(1)
    DT[0] << value
  end
end

values = (1..200).to_a
values.each { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].size >= 10
end

sleep(1)

consumer = setup_rdkafka_consumer
consumer.subscribe(DT.topic)

first_continued = nil

consumer.each do |message|
  first_continued = message
  break
end

# Intermediate jobs should be processed
assert first_continued.offset > 0

first_continued = nil

consumer.close
