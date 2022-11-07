# frozen_string_literal: true

# Karafka should not allow for using VP with MOM

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 10
end

guarded = []

begin
  draw_routes do
    consumer_group DT.consumer_group do
      topic DT.topic do
        consumer Class.new(Karafka::BaseConsumer)
        virtual_partitions(
          partitioner: ->(msg) { msg.raw_payload }
        )
        manual_offset_management true
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << 1
end

assert_equal [1], guarded
