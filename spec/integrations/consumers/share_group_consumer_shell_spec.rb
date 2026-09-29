# frozen_string_literal: true

# The share-group consumer (KIP-932) can be defined and introspected as a share consumer and
# exposes the per-record acknowledgement API (mark_consumed/released/rejected, sync and async).
# The advanced parts (delayed release, lock extension) are still not implemented and raise, and
# share groups cannot run in the swarm yet (the swarm guard raises). Consumer-group consumers are
# entirely unaffected by the consumer class hierarchy.

setup_karafka

# (a) A share-group consumer subclass can be defined via the user-facing Karafka::ShareConsumer
# primitive (a flat alias of Consumers::ShareGroup) and introspects as share
assert Karafka::ShareConsumer.equal?(Karafka::Consumers::ShareGroup)

class MyShareConsumer < Karafka::ShareConsumer
  def consume
    nil
  end
end

share_consumer = MyShareConsumer.new

assert MyShareConsumer < Karafka::Consumers::Base
assert_equal :share, share_consumer.group_type
assert share_consumer.share_group?
assert !share_consumer.consumer_group?

# (b) The acknowledgement API is present, with async and sync (bang) variants plus the
# consumer-group-consistent aliases
%i[
  mark_as_consumed mark_as_consumed! mark_consumed mark_consumed!
  mark_as_released mark_as_released! mark_released mark_released!
  mark_as_rejected mark_as_rejected! mark_rejected mark_rejected!
].each do |ack_method|
  assert share_consumer.respond_to?(ack_method), ack_method
end

# (b.1) The advanced acknowledgement parts are not implemented yet and raise
message = Object.new

extend_lock_raised = false

begin
  share_consumer.extend_lock!(message)
rescue NotImplementedError
  extend_lock_raised = true
end

assert extend_lock_raised

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

# (d) A consumer-group consumer on a share group is rejected at draw, so a CG consumer can never
# run on a share-group setup
rejected = false

begin
  draw_routes(create_topics: false) do
    share_group "sg-wrong-consumer" do
      topic "sg-topic" do
        active(false)
        consumer CgConsumer
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?("share consumer inheriting from Karafka::ShareConsumer"), e.message

  rejected = true
end

assert rejected

clear_app_draws

# (e) Share groups run under `karafka server` but not in the swarm yet - the swarm guard raises
guarded = false

draw_routes(create_topics: false) do
  share_group "sg" do
    topic "sg-topic" do
      consumer MyShareConsumer
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
