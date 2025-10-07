# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Pausing < Base
          # Expansion allowing for a per topic pause strategy definitions
          module Topic
            # This method calls the parent class initializer and then sets up the
            # extra instance variable to nil. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              super
              @pausing = nil
            end

            # Allows for per-topic pausing strategy setting
            #
            # @param timeout [Integer] how long should we wait upon processing error (milliseconds)
            # @param max_timeout [Integer] what is the max timeout in case of an exponential
            #   backoff (milliseconds)
            # @param with_exponential_backoff [Boolean] should we use exponential backoff
            # @return [Config] pausing config object
            def pause(timeout: nil, max_timeout: nil, with_exponential_backoff: nil)
              # If no arguments provided, just return or initialize the config
              return pausing if timeout.nil? && max_timeout.nil? && with_exponential_backoff.nil?

              # Update instance variables for backwards compatibility
              # This ensures code reading @pause_timeout directly or via the inherited getter
              # will get the correct values
              @pause_timeout = timeout if timeout
              @pause_max_timeout = max_timeout if max_timeout

              unless with_exponential_backoff.nil?
                @pause_with_exponential_backoff = with_exponential_backoff
              end

              # Create or update the config
              @pausing ||= Config.new(
                active: false,
                timeout: @pause_timeout || Karafka::App.config.pause.timeout,
                max_timeout: @pause_max_timeout || Karafka::App.config.pause.max_timeout,
                with_exponential_backoff: if @pause_with_exponential_backoff.nil?
                                            Karafka::App.config.pause.with_exponential_backoff
                                          else
                                            @pause_with_exponential_backoff
                                          end
              )

              @pausing.timeout = timeout if timeout
              @pausing.max_timeout = max_timeout if max_timeout

              unless with_exponential_backoff.nil?
                @pausing.with_exponential_backoff = with_exponential_backoff
              end

              @pausing.active = true

              @pausing
            end

            # @return [Config] pausing configuration object
            def pausing
              @pausing ||= Config.new(
                active: false,
                timeout: @pause_timeout || Karafka::App.config.pause.timeout,
                max_timeout: @pause_max_timeout || Karafka::App.config.pause.max_timeout,
                with_exponential_backoff: if @pause_with_exponential_backoff.nil?
                                            Karafka::App.config.pause.with_exponential_backoff
                                          else
                                            @pause_with_exponential_backoff
                                          end
              )
            end

            # @return [Boolean] is pausing explicitly configured
            def pausing?
              pausing.active?
            end

            # @return [Hash] topic with all its native configuration options plus pausing settings
            def to_h
              super.merge(
                pausing: pausing.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
