# frozen_string_literal: true

# Checker for matching system notifications events with method names to look for typos, etc
module NotificationsChecker
  class << self
    # @return [Array<String>] map of events to methods
    def events_methods
      Karafka::Instrumentation::Notifications::EVENTS.map { |event| "on_#{event.tr(".", "_")}" }
    end

    # @param object [Object] object that should have `on_*` methods for notifications listening
    # @return [Array<String>] methods that match notifications format
    def object_events_methods(object)
      object.methods.map(&:to_s).select { |met| met.start_with?("on_") }
    end

    # @param object [Object] object we want to test
    # @return [Boolean] true if all matches or false if there are methods that do not match events
    def valid?(object)
      (object_events_methods(object) - events_methods).empty?
    end
  end
end
