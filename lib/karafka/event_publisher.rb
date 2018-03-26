# frozen_string_literal: true

module Karafka
  class EventPublisher
    include Dry::Events::Publisher[:karafka_event_publisher]

    register_event 'app.after_init'
    register_event 'connection.listener.before_fetch_loop'
  end
end
