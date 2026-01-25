# frozen_string_literal: true

# When having defaults but also having explicit definitions, defaults should not overwrite explicit
# for admin

setup_karafka

class Custom
  def initialize(result)
    @result = result
  end

  def call(_message)
    @result
  end
end

draw_routes do
  defaults do
    deserializers(
      payload: Custom.new(1),
      key: Custom.new(2),
      headers: Custom.new(3)
    )
  end

  topic DT.topic do
    active(false)
    deserializers(
      payload: Custom.new(4),
      key: Custom.new(5),
      headers: Custom.new(6)
    )
  end
end

produce(DT.topic, "10")

message = Karafka::Admin.read_topic(DT.topic, 0, 1).last
assert_equal 4, message.payload
assert_equal 5, message.key
assert_equal 6, message.headers
