# frozen_string_literal: true

module Karafka
  module Instrumentation
    # EventPublisher is responsible for publishing events related to application lifecycle events.
    class EventPublisher
      include Dry::Events::Publisher[:karafka_event_publisher]

      # List of Karafka application lifecycle events we support
      EVENTS = %w[
        after_init
        before_fetch_loop
      ].freeze

      private_constant :EVENTS

      EVENTS.each(&method(:register_event))
    end
  end
end
