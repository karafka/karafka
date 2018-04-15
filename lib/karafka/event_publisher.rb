# frozen_string_literal: true

module Karafka
  # EventPublisher is responsible for publishing events related to application lifecycle events.
  class EventPublisher
    include Dry::Events::Publisher[:karafka_event_publisher]

    # List of Karafka application lifecycle events we support
    EVENTS = %w[
      app.after_init
      connection.listener.before_fetch_loop
    ].freeze

    EVENTS.each { |event| register_event event }
  end
end
