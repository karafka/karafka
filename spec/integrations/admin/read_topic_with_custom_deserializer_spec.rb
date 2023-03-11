# frozen_string_literal: true

# When using read_topic with topic that is inactive, the deserializer resolution should work
# and properly defined deserializer should be used

setup_karafka

class Custom
  def call(_message)
    1
  end
end

draw_routes do
  topic DT.topic do
    active false
    deserializer Custom.new
  end
end

produce(DT.topic, '10')

messages = Karafka::Admin.read_topic(DT.topic, 0, 1)
assert_equal 1, messages.last.payload
