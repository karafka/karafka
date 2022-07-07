# frozen_string_literal: true

# When manual offset management is on, upon error Karafka should start again from the place
# it had in the checkpoint, not from the beginning. We check here that this works well when we
# commit "from time to time", not every message

setup_karafka(allow_errors: true) do |config|
  config.manual_offset_management = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    @consumed ||= 0

    messages.each do |message|
      @consumed += 1

      raise StandardError if @consumed == 50

      # After 25 we should mark as consumed
      mark_as_consumed!(message) if @consumed == 24

      DataCollector[0] << message.raw_payload
    end
  end
end

draw_routes(Consumer)

elements = Array.new(100) { SecureRandom.uuid }
elements.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  DataCollector[0].size >= 125
end

# We need unique as due to error and manual offset, some will be duplicated
assert_equal elements, DataCollector[0].uniq
assert_equal 125, DataCollector[0].size
assert_equal 1, DataCollector.data.size
