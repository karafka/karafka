# frozen_string_literal: true

# Karafka should reset the error count after seeking as it is a non-error flow

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless @first_done
      @first_done = true

      return
    end

    @raised ||= []

    unless @raised.size >= 3
      @raised << true

      raise
    end

    if @seeked
      DT[:post] << attempt
    else
      @seeked = true

      seek(0)
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:post].size >= 2
end

assert DT[:post].size >= 2
assert_equal [1], DT[:post].uniq
