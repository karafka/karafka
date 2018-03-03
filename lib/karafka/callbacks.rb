# frozen_string_literal: true

module Karafka
  # Additional callbacks that are used to trigger some things in given places during the
  # system lifecycle
  # @note Those callbacks aren't the same as consumer callbacks as they are not related to the
  #   lifecycle of particular messages fetches but rather to the internal flow process.
  #   They cannot be defined on a consumer callback level because for some of those,
  #   there aren't consumers in the memory yet and/or they aren't per consumer thread
  module Callbacks
    # Types of system callbacks that we have that are not related to consumers
    TYPES = %i[
      after_init
      before_fetch_loop
    ].freeze

    class << self
      TYPES.each do |callback_type|
        # Executes given callbacks set at a given moment with provided arguments
        define_method callback_type do |*args|
          Karafka::App
            .config
            .callbacks
            .send(callback_type)
            .each { |callback| callback.call(*args) }
        end
      end
    end
  end
end
