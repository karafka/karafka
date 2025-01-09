# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Manual seek per user request should super-seed the filters.

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << messages.first.offset

    seek(3)
  end
end

class Filter < Karafka::Pro::Processing::Filters::Base
  def apply!(messages)
    @applied = true

    messages
  end

  def action
    :seek
  end

  def applied?
    true
  end

  def timeout
    0
  end

  def cursor
    raise
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    filter(->(*) { Filter.new })
  end
end

produce_many(DT.topics[0], DT.uuids(10))

start_karafka_and_wait_until do
  DT[0].size >= 10
end

assert_equal [0, 3], DT[0].uniq
