# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Delaying < Base
          # Topic delaying API extensions
          module Topic
            # @param delay [Integer, nil] minimum age of a message we want to process
            def delaying(delay = nil)
              # Those settings are used for validation
              @delaying ||= begin
                config = Config.new(active: !delay.nil?, delay: delay)

                if config.active?
                  factory = ->(*) { Pro::Processing::Filters::Delayer.new(delay) }
                  filter(factory)
                end

                config
              end
            end

            # Just an alias for nice API
            #
            # @param args [Array] Anything `#delaying` accepts
            def delay_by(*args)
              delaying(*args)
            end

            # @return [Boolean] is a given job delaying
            def delaying?
              delaying.active?
            end

            # @return [Hash] topic with all its native configuration options plus delaying
            def to_h
              super.merge(
                delaying: delaying.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
