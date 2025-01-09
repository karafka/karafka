# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Expiring < Base
          # Topic expiring API extensions
          module Topic
            # @param ttl [Integer, nil] maximum time in ms a message is considered alive
            def expiring(ttl = nil)
              # Those settings are used for validation
              @expiring ||= begin
                config = Config.new(active: !ttl.nil?, ttl: ttl)

                if config.active?
                  factory = ->(*) { Pro::Processing::Filters::Expirer.new(ttl) }
                  filter(factory)
                end

                config
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
