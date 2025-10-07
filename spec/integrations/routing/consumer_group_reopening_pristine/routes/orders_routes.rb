# frozen_string_literal: true

# Orders domain routing configuration
# This file reopens the 'main_app' consumer group to add order-related topics
Karafka::App.routes.draw do
  consumer_group 'main_app' do
    topic 'orders.placed' do
      consumer OrdersConsumer
      initial_offset 'earliest'
    end

    topic 'orders.completed' do
      consumer OrdersConsumer
      initial_offset 'earliest'
    end
  end
end
