# frozen_string_literal: true

# Karafka should not allow for using VP with DLQ

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
end

guarded = []

begin
  draw_routes do
    consumer_group DT.consumer_group do
      topic DT.topic do
        consumer Class.new(Karafka::Pro::BaseConsumer)
        virtual_partitions(
          partitioner: ->(msg) { msg.raw_payload }
        )
        dead_letter_queue topic: 'test'
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << 1
end

assert_equal [1], guarded
