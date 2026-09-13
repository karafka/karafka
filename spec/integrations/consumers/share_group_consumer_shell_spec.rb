# frozen_string_literal: true

# The share-group consumer (KIP-932) exists as a subclassable shell: it can be defined and
# introspected as a share consumer and exposes the acknowledgement API as not-yet-implemented
# stubs, but share groups still cannot be RUN (the startup guard raises). Consumer-group consumers
# are entirely unaffected by the introduction of the consumer class hierarchy.

setup_karafka

# (a) A share-group consumer subclass can be defined and introspects as share
class ShareConsumer < Karafka::Consumers::ShareGroup
  def consume
    nil
  end
end

share_consumer = ShareConsumer.new

assert ShareConsumer < Karafka::Consumers::Base
assert_equal :share, share_consumer.group_type
assert share_consumer.share_group?
assert !share_consumer.consumer_group?

# (b) The acknowledgement API stubs raise until the runtime lands
message = Object.new

%i[mark_accepted mark_rejected extend_lock!].each do |ack_method|
  raised = false

  begin
    share_consumer.public_send(ack_method, message)
  rescue NotImplementedError
    raised = true
  end

  assert raised, ack_method
end

released_raised = false

begin
  share_consumer.mark_released(message, delay: 1_000)
rescue NotImplementedError
  released_raised = true
end

assert released_raised

# (c) Existing consumer-group consumers are unaffected
class CgConsumer < Karafka::BaseConsumer
  def consume
    nil
  end
end

assert CgConsumer < Karafka::Consumers::ConsumerGroup
assert Karafka::BaseConsumer.equal?(Karafka::Consumers::ConsumerGroup)
assert CgConsumer.new.respond_to?(:pause)
assert CgConsumer.new.respond_to?(:seek)
assert CgConsumer.new.consumer_group?

# A consumer-group route draws and validates fine
draw_routes(create_topics: false) do
  consumer_group "cg" do
    topic "cg-topic" do
      active(false)
      consumer CgConsumer
    end
  end
end

assert_equal 1, Karafka::App.routes.consumer_groups.size

clear_app_draws

# (d) Share groups still cannot run - the startup guard raises even with a valid share consumer
guarded = false

draw_routes(create_topics: false) do
  share_group "sg" do
    topic "sg-topic" do
      consumer ShareConsumer
    end
  end
end

begin
  Karafka::App.verify_share_groups_inactive!
rescue Karafka::Errors::ShareGroupsNotImplementedError => e
  assert e.message.include?("sg"), e.message

  guarded = true
end

assert guarded
