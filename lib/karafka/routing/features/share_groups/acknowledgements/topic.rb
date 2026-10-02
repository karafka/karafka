# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module ShareGroups
        class Acknowledgements < Base
          # Routing topic acknowledgements API
          module Topic
            # This method sets up the extra instance variable to nil before calling
            # the parent class initializer. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              @acknowledgements = nil
              super
            end

            # @param unacknowledged [Symbol] how records the consumer did not acknowledge should be
            #   acknowledged after a successful consumption: `:release` (redelivery, default),
            #   `:accept` or `:reject`
            def acknowledgements(unacknowledged: :release)
              @acknowledgements ||= Config.new(
                active: true,
                unacknowledged: unacknowledged
              )
            end

            # @return [Boolean] acknowledgements are always active
            def acknowledgements?
              acknowledgements.active?
            end

            # @return [Hash] topic setup hash
            def to_h
              super.merge(
                acknowledgements: acknowledgements.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
