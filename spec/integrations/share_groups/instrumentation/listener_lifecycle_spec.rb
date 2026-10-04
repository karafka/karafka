# frozen_string_literal: true

# Share group (KIP-932) listener should publish the fetch loop events (with the share listener,
# client and subscription group) and all the listener status events, and log the subscription.

PUBLISHED_STATES = %w[
  connection.listener.pending
  connection.listener.starting
  connection.listener.running
  connection.listener.quieting
  connection.listener.quiet
  connection.listener.stopping
  connection.listener.stopped
].freeze

PUBLISHED_STATES.each do |state|
  Karafka::App.monitor.subscribe(state) do
    DT[:states] << state
  end
end

strio = StringIO.new

setup_karafka do |config|
  config.logger = Logger.new(strio)
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| mark_as_accepted(message) }
    DT[0] << true
  end
end

%w[
  connection.listener.before_fetch_loop
  connection.listener.fetch_loop
  connection.listener.after_fetch_loop
].each do |event_name|
  Karafka::App.monitor.subscribe(event_name) do |event|
    DT[event_name] << event
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

share_sg = Karafka::App.subscription_groups.values.flatten.find { |sg| sg.group.share_group? }

produce(DT.topic, "1")

start_karafka_and_wait_until do
  DT.key?(0)
end

# We need to sleep as state changes propagate in a separate thread
sleep(0.01) until DT[:states].size >= PUBLISHED_STATES.size

assert_equal PUBLISHED_STATES, DT[:states]

assert_equal 1, DT["connection.listener.before_fetch_loop"].size
assert_equal 1, DT["connection.listener.after_fetch_loop"].size
assert DT["connection.listener.fetch_loop"].size >= 1

%w[
  connection.listener.before_fetch_loop
  connection.listener.fetch_loop
  connection.listener.after_fetch_loop
].each do |event_name|
  DT[event_name].each do |event|
    assert event[:caller].is_a?(Karafka::Connection::ShareGroups::Listener), event_name
    assert event[:client].is_a?(Karafka::Connection::ShareGroups::Client), event_name
    assert_equal share_sg, event[:subscription_group]
  end
end

assert strio.string.include?(
  "Group #{share_sg.group.id}/#{share_sg.id} subscribing to topics: #{DT.topic}"
)
