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
