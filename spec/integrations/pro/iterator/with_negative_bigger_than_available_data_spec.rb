# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we request more data with negative lookup than there is in the partition, we should pick
# as much as there is and no more.

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

2.times { produce(DT.topic, '1') }

iterator = Karafka::Pro::Iterator.new(
  { DT.topic => { 0 => -100 } }
)

data = []

iterator.each { |message| data << message.offset }

assert_equal [0, 1], data
