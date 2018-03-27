# frozen_string_literal: true

module Karafka
  # EventPublisher is responsible for publishing events related to application lifecycle events.
  class EventPublisher
    include Dry::Events::Publisher[:karafka_event_publisher]

    register_event 'app.after_init'
    register_event 'connection.listener.before_fetch_loop'
  end
end
