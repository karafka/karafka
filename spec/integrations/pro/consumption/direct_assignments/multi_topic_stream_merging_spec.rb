# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When using direct assignments, we should be able to maintain a window and merge data from
# several streams
#
# Note, that this example is a simplification and does not take into consideration lags caused
# by sudden data spikes in one of the topics. It aims to illustrate the basics of stream merging.

# What we do here is simple: we publish users creation events and we publish their actions events
# Events cannot happen before user is created but since we have two topics, their delivery times
# may vary. We merge those two topics and dispatch the target data into "users_events" target topic

# This example is simplified. Offset management is not correct for production-grade flow.

setup_karafka do |config|
  config.concurrency = 10
end

# A simple merger that can deal with  merging users and their events into one flow
class Merger
  include Singleton

  attr_accessor :actions_subscription_group, :subscription_groups_coordinator

  def initialize
    @users = {}
    @incoming_actions = []
    @actions_ahead = false
    @mutex = Mutex.new
    @stopped = false
  end

  def call(messages, type:)
    return if @stopped

    @mutex.synchronize do
      case type
      # Since we always need users, there's no issue in just storing it
      when :users
        messages.payloads.each do |payload|
          @users[payload['id']] = payload
        end
      when :actions
        messages.payloads.each do |payload|
          @incoming_actions << payload
        end
      end

      dispatch_if_merge_possible

      return unless subscription_groups_coordinator

      # If we started getting events for users we do not have, we just pause until we catch up
      # on the users topic
      if @actions_ahead
        @paused = true
        subscription_groups_coordinator.pause(actions_subscription_group)
      elsif @paused
        @paused = false
        subscription_groups_coordinator.resume(actions_subscription_group)
      end
    end
  end

  def stop
    @mutex.synchronize do
      @stopped = true

      return unless @paused

      @paused = false
      # We need to unlock on stop. Otherwise it would block full shutdown
      subscription_groups_coordinator.resume(actions_subscription_group)
    end
  end

  private

  def dispatch_if_merge_possible
    mergeable = @incoming_actions.all? do |action|
      @users.key?(action['user_id'])
    end

    if mergeable
      @incoming_actions.each do |action|
        user = @users.fetch(action['user_id'])

        Karafka.producer.produce_async(
          topic: DT.topics[2],
          payload: action.merge(user: user).to_json
        )
      end

      @actions_ahead = false
      @incoming_actions.clear
    else
      @actions_ahead = true
    end
  end
end

# Initialize prior so no risk of race-condition
Merger.instance

class UsersEventsConsumer < Karafka::BaseConsumer
  def consume
    Merger.instance.call(messages, type: :users)
  end

  def shutdown
    Merger.instance.stop
  end
end

class ActionsEventsConsumer < Karafka::BaseConsumer
  def consume
    merger = Merger.instance

    merger.actions_subscription_group ||= topic.subscription_group
    merger.subscription_groups_coordinator ||= subscription_groups_coordinator

    merger.call(messages, type: :actions)
  end
end

class ValidationConsumer < Karafka::BaseConsumer
  def consume
    messages.payloads.each do |event|
      DT[:merged] << event
    end
  end
end

draw_routes do
  consumer_group "#{DT.consumer_group}_merger" do
    subscription_group do
      topic DT.topics[0] do
        consumer UsersEventsConsumer
        assign(true)
      end
    end

    subscription_group do
      topic DT.topics[1] do
        consumer ActionsEventsConsumer
        assign(true)
      end
    end
  end

  consumer_group "#{DT.consumer_group}_verifications" do
    topic DT.topics[2] do
      consumer ValidationConsumer
    end
  end
end

RANDOM_BOOL = [true, false].freeze

Thread.new do
  loop do
    user_id = SecureRandom.uuid
    user_event = { id: user_id, time: Time.now.to_f }.to_json
    action_event = { user_id: user_id, val: rand, time: Time.now.to_f }.to_json

    if RANDOM_BOOL.sample
      produce(DT.topics[0], user_event)
      sleep(rand / 10)
      produce(DT.topics[1], action_event)
    else
      # Force them to go out of sync by sending first action
      produce(DT.topics[1], action_event)
      sleep(rand / 10)
      produce(DT.topics[0], user_event)
    end
  end
rescue WaterDrop::Errors::ProducerClosedError
  nil
end

start_karafka_and_wait_until do
  DT[:merged].size >= 100
end

DT[:merged].each do |event|
  assert event['time'] > event['user']['time']
end
