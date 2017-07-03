# frozen_string_literal: true

module Karafka
  # App status monitor
  class Status
    include Singleton

    # Available states and their transitions
    STATES = {
      initializing: :initialize!,
      running: :run!,
      stopped: :stop!
    }.freeze

    STATES.each do |state, transition|
      define_method :"#{state}?" do
        @status == state
      end

      define_method transition do
        @status = state
      end
    end
  end
end
