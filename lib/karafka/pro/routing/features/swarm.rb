# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        # Karafka Pro Swarm extensions to the routing
        # They allow for more granular work assignment in the swarm
        class Swarm < Base
          class << self
            # Binds our routing validation contract prior to warmup in the supervisor, so we can
            # run it when all the context should be there (config + full routing)
            #
            # @param config [Karafka::Core::Configurable::Node] app config
            def post_setup(config)
              config.monitor.subscribe('app.before_warmup') do
                Contracts::Routing.new.validate!(config.internal.routing.builder)
              end
            end
          end
        end
      end
    end
  end
end
