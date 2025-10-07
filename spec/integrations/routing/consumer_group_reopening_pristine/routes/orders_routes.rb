# frozen_string_literal: true

# Orders domain routing configuration
# This file reopens the same consumer group to add order-related topics
Karafka::App.routes.draw do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[2] do
      consumer OrdersConsumer
      initial_offset 'earliest'
    end

    topic DT.topics[3] do
      consumer OrdersConsumer
      initial_offset 'earliest'
    end
  end
end
