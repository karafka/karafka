# frozen_string_literal: true

# When starting from latest offset and having error on first run, Karafka has no offset to write
# as the first one, thus if restarted, it will against start from "latest".

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.initial_offset = 'latest'
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless @marked
      @marked = true

      previous_to_latest = messages.first.offset - 1
      # This will force Karafka to "accept" lower offset which is not something that is recommended
      # usually but can be beneficial in this particular case
      coordinator.seek_offset = previous_to_latest

      mark_as_consumed!(
        Karafka::Messages::Seek.new(topic.name, partition, previous_to_latest)
      )
    end

    DT[:done] << true

    raise
  end
end

draw_routes(Consumer)

# Produce one so we don't start from 0
produce(DT.topic, '')

start_karafka_and_wait_until do
  wait_for_assignments

  unless @sent
    @sent = true
    produce(DT.topic, '')
  end

  DT.key?(:done)
end

# Since we force marked as consumed the latest - 1, it should start again from the latest,
# whic is in our case first message dispatched after server started
assert_equal 1, fetch_next_offset
