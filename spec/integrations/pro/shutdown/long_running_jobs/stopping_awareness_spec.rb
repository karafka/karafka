# frozen_string_literal: true

# When running a long running job, we should be able to detect that Karafka is stopping so we can
# early exit the job.

# Note, that for this to work correctly in regards to offsets, manual offset management need to
# be turned on.

setup_karafka do |config|
  config.concurrency = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    # We use loop so in case this would not work, it will timeout and raise an error
    loop do
      break if Karafka::App.stopping?

      DT[:done] << true

      sleep(0.1)
    end

    DT[:aware] << true
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      long_running_job true
      manual_offset_management true
    end
  end
end

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[:done].size >= 1
end

assert_equal [true], DT[:aware]
