# frozen_string_literal: true

# Karafka with lrj ActiveJob when finishing in the middle of jobs on shutdown, should pick up
# where it stopped when started again
#
# We test it by starting a new consumer just to get the first message offset

setup_karafka do |config|
  # This will ensure we get more jobs in one go
  config.max_wait_time = 5_000
  config.license.token = pro_license_token
end

setup_active_job

draw_routes do
  consumer_group DataCollector.consumer_group do
    active_job_topic DataCollector.topic do
      long_running_job true
      manual_offset_management true
    end
  end
end

class Job < ActiveJob::Base
  queue_as DataCollector.topic

  karafka_options(
    dispatch_method: :produce_sync
  )

  def perform(value)
    # We add sleep to simulate work being done, so it ain't done too fast before we shutdown
    if DataCollector[:stopping].size.zero?
      DataCollector[:stopping] << true
      sleep(5)
    end

    DataCollector[0] << value
  end
end

5.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  !DataCollector[:stopping].size.zero?
end

# Give Karafka time to finalize everything
sleep(2)

# We need a second producer to check where fi started from
consumer = setup_rdkafka_consumer

consumer.subscribe(DataCollector.topic)

consumer.each do |message|
  DataCollector[1] << message.offset

  # One is enough
  break
end

consumer.close

assert_equal DataCollector[0][0] + 1, DataCollector[1][0]
