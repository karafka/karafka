# frozen_string_literal: true

# This Karafka component is a Pro component.
# All of the commercial components are present in the lib/karafka/pro directory of this repository
# and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
module Karafka
  module Pro
    # Loader requires and loads all the pro components only when they are needed
    class Loader
      class << self
        # Loads all the pro components and configures them wherever it is expected
        # @param config [Dry::Configurable::Config] whole app config that we can alter with pro
        #   components
        def setup(config)
          raise config
        end
      end
    end
  end
end
