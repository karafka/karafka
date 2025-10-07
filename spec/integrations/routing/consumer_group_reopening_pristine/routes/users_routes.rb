# frozen_string_literal: true

# Users domain routing configuration
# This file defines user-related topics in the 'main_app' consumer group
Karafka::App.routes.draw do
  consumer_group 'main_app' do
    topic 'users.created' do
      consumer UsersConsumer
      initial_offset 'earliest'
    end

    topic 'users.updated' do
      consumer UsersConsumer
      initial_offset 'earliest'
    end
  end
end
