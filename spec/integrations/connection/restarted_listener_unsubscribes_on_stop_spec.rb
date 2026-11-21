# frozen_string_literal: true

# A listener that was stopped and started again (as Pro dynamic multiplexing does) should
# unsubscribe again before closing on its next stop, not only on the first one.
# The second subscription group keeps running, so the jobs queue stays open on the restart.

setup_karafka

module UnsubscribeTracker
  private

  def unsubscribe
    DT[:unsubscribes] << subscription_group.name
    super
  end
end

Karafka::Connection::ConsumerGroups::Client.prepend(UnsubscribeTracker)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[topic.name] << messages.size
    DT[:consumed_after_restart] << true if DT.key?(:restart) && topic.name == DT.topics[0]
  end
end

draw_routes do
  subscription_group :restarted do
    topic DT.topics[0] do
      consumer Consumer
    end
  end

  subscription_group :running do
    topic DT.topics[1] do
      consumer Consumer
    end
  end
end

produce_many(DT.topics[0], DT.uuids(10))
produce_many(DT.topics[1], DT.uuids(10))

listener = nil

start_karafka_and_wait_until do
  listener ||= Karafka::Server.listeners.find do |sg_listener|
    sg_listener.subscription_group.name == "restarted"
  end

  if DT.key?(DT.topics[0]) && DT.key?(DT.topics[1]) && !DT.key?(:stop)
    DT[:stop] << true
    listener.stop!
  end

  if DT.key?(:stop) && !DT.key?(:restart) && listener.stopped?
    DT[:restart] << true
    produce_many(DT.topics[0], DT.uuids(10))
    listener.start!
  end

  DT.key?(:consumed_after_restart)
end

# The restarted listener unsubscribes on its first stop and again on the shutdown stop
assert_equal 2, DT[:unsubscribes].count("restarted")
assert_equal 1, DT[:unsubscribes].count("running")
