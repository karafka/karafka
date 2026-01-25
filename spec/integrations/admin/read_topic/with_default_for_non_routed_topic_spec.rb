# frozen_string_literal: true

# When using read_topic with a topic that is not part of the routing, it should use the defaults
# deserializers defined if they are present instead of the "total" framework defaults

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
end

produce(DT.topic, "10")

message = Karafka::Admin.read_topic(DT.topic, 0, 1).last
assert_equal 1, message.payload
assert_equal 2, message.key
assert_equal 3, message.headers
