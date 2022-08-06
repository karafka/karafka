# frozen_string_literal: true

# Karafka even when a batch is fetched, should pause on message that failed as long as marking as
# consumed happened. It should not restart whole batch if marking happened

setup_karafka(allow_errors: true) do |config|
  config.max_wait_time = 5_000
  config.max_messages = 1_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset
    end

    # We need more messages to check this and sometimes we get one and then more
    return if messages.count <= 1

    @count ||= 0
    @count += 1

    return unless @count == 1

    DT[:last_good] = messages.to_a[-2].offset
    # This and previous messages should not appear twice
    mark_as_consumed messages.to_a[-2]

    DT[:repeated] = messages.to_a[-1].offset

    raise StandardError
  end
end

draw_routes(Consumer)

100.times { produce(DT.topic, '1') }

start_karafka_and_wait_until do
  DT[:offsets].size >= 101
end

# The message on which we failed should have been processed twice
assert_equal 2, DT[:offsets].count(DT[:repeated])

# Messages prior to one that failed should not appear twice
DT[:offsets].each do |offset|
  next if offset >= DT[:repeated]

  assert_equal 1, DT[:offsets].count(offset)
end
