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
        class Expiring < Base
          # Topic expiring API extensions
          module Topic
            # @param ttl [Integer, nil] maximum time in ms a message is considered alive
            def expiring(ttl = Karafka::Routing::Default.new)
              # Those settings are used for validation
              @expiring ||= Config.new(active: false, ttl: ttl)
              begin
                @expiring.ttl = ttl
                @expiring.active = !@expiring.ttl.nil?

                if @expiring.active?
                  factory = ->(*) { Pro::Processing::Filters::Expirer.new(ttl) }
                  filter(factory)
                end

                @expiring
              end
            end

            # Just an alias for nice API
            #
            # @param args [Array] Anything `#expiring` accepts
            def expire_in(*args)
              expiring(*args)
            end

            # @return [Boolean] is a given job expiring
            def expiring?
              expiring.active?
            end

            # @return [Hash] topic with all its native configuration options plus expiring
            def to_h
              super.merge(
                expiring: expiring.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
