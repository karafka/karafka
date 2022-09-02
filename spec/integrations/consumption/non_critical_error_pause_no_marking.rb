# frozen_string_literal: true

# Karafka when no marking happens should restart whole batch

setup_karafka(allow_errors: true) do |config|
  config.max_wait_time = 5_000
  config.max_messages = 50
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

    DT[:first_in] = messages.first.offset
    DT[:last_in] = messages.last.offset

    raise StandardError
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:offsets].size >= 101
end

DT[:offsets].each do |offset|
  if offset < DT[:first_in]
    assert_equal 1, DT[:offsets].count(offset)

    next
  end

  if offset <= DT[:last_in]
    assert_equal 2, DT[:offsets].count(offset)

    next
  end

  assert_equal 1, DT[:offsets].count(offset)
end
