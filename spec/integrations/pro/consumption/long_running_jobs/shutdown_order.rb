# frozen_string_literal: true

# When running lrj, Karafka should never run the shutdown operations while consumption is in
# progress

setup_karafka do |config|
  config.max_messages = 1
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.license.token = pro_license_token
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    sleep(15)

    DT[0] << Time.now
  end

  def shutdown
    DT[1] << Time.now
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      long_running_job true
    end
  end
end

5.times { produce(DT.topic, '1') }

start_karafka_and_wait_until do
  DT[0].size >= 1
end

assert DT[0].last < DT[1].last
