# frozen_string_literal: true

# This case aims to illustrate that with a non-homogenous topics setup with different consumption
# costs better scheduling can have significant impact. In this scenario we can gain up to 15%
# of performance just by arranging the jobs well

# @note Due to instability of the CI, we cannot measure times of execution for really short times
#   here. The problem is, that the CI randomly hangs. That's why we use a value big enough to make
#   those hickups insignificant. Please look into the benchmarks if you are interested in the specs
#   for lower IO per message.

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 3
  config.max_wait_time = 1_000
  config.max_messages = 100
  # This will ensure that for both runs we start from the same message
  config.manual_offset_management = true
  # Disable logging not to flush stdout with irrelevant info
  config.logger.level = ::Logger::FATAL
end

Karafka::App.producer.config.logger.level = ::Logger::FATAL

class Consumer < Karafka::BaseConsumer
  def consume
    # This sleep time will emulate various costs of processing data in given topics
    ts = DataCollector.topics.index(topic.name)
    cpm = (ts % 2).zero? ? 0.1 : 0.01

    messages.each do
      sleep(cpm)
      DataCollector.data[0] << true
    end
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    DataCollector.topics.first(10).each do |topic_name|
      topic topic_name do
        consumer Consumer
      end

      Thread.new do
        begin
          loop do
            produce(topic_name, SecureRandom.uuid)
            sleep(0.1)
          end
        rescue WaterDrop::Errors::ProducerClosedError
        end
      end
    end
  end
end

Karafka.monitor.subscribe('')

tt = Time.now.to_f

start_karafka_and_wait_until do
  DataCollector.data.values.flatten.size >= 2_000
end

p Karafka::App.config.internal.scheduler

p "#{(Time.now.to_f - tt) * 1000}"
