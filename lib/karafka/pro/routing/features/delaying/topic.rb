# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
