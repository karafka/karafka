# frozen_string_literal: true

# Users domain routing configuration
# This file defines user-related topics in a shared consumer group
Karafka::App.routes.draw do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[0] do
      consumer UsersConsumer
      initial_offset "earliest"
    end

    topic DT.topics[1] do
      consumer UsersConsumer
      initial_offset "earliest"
    end
  end
end
