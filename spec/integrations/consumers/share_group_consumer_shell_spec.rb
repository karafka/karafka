# frozen_string_literal: true

# The share-group consumer (KIP-932) can be defined and introspected as a share consumer and
# exposes the per-record acknowledgement API (mark_as_accepted/released/rejected, sync and async).
# Advanced parts (delayed release, lock extension) are Pro/future and are simply not present.
# Share groups cannot run in the swarm yet (the swarm guard raises). Consumer-group consumers are
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

# (b) The acknowledgement API is present, with async and sync (bang) variants
%i[
  mark_as_accepted mark_as_accepted!
  mark_as_released mark_as_released!
  mark_as_rejected mark_as_rejected!
].each do |ack_method|
  assert share_consumer.respond_to?(ack_method), ack_method
end

# (b.1) Advanced parts (delayed release, lock extension) are Pro/future and are not present
assert !share_consumer.respond_to?(:extend_lock!)

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
