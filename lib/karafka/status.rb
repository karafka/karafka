# frozen_string_literal: true

module Karafka
  # App status monitor
  class Status
    include Singleton

    # Available states and their transitions
    STATES = {
      initializing: :initialize!,
      initialized: :initialized!,
      running: :run!,
      stopping: :stop!
    }.freeze

    private_constant :STATES

    STATES.each do |state, transition|
      define_method :"#{state}?" do
        @status == state
      end

      define_method transition do
        @status = state
        # Trap context disallows to run certain things that we instrument
        # so the state changes are executed from a separate thread
        Thread.new { Karafka.monitor.instrument("app.#{state}", {}) }.join
      end
    end
  end
end
