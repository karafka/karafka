# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we define scheduled messages setup, it should have correct offset position configuration
# for offset reset

setup_karafka do |config|
  config.kafka[:'auto.offset.reset'] = 'latest'
end

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    active(false)
  end

  scheduled_messages(DT.topics[2])
end

cg = Karafka::App.routes.to_a.first

assert_equal 'earliest', cg.topics[0].kafka[:'auto.offset.reset']
assert_equal 'latest', cg.topics[1].kafka[:'auto.offset.reset']
assert_equal 'earliest', cg.topics[2].kafka[:'auto.offset.reset']
assert_equal 'latest', cg.topics[3].kafka[:'auto.offset.reset']
