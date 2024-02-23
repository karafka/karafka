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
        class Swarm < Base
          # Topic swarm API extensions
          module Topic
            # Allows defining swarm routing topic settings
            # @param nodes [Range, Array] range of nodes ids or array with nodes ids for which we
            #   should run given topic
            def swarm(nodes: (0...Karafka::App.config.swarm.nodes))
              @swarm ||= Config.new(active: true, nodes: nodes)
            end

            # @return [true] swarm setup is always true. May not be in use but is active
            def swarm?
              swarm.active?
            end

            # @return [Boolean] should this topic be active. In the context of swarm it is only
            #   active when swarm routing setup does not limit nodes on which it should operate
            def active?
              node = Karafka::App.config.swarm.node

              return super unless node

              super && swarm.nodes.include?(node.id)
            end

            # @return [Hash] topic with all its native configuration options plus swarm
            def to_h
              super.merge(
                swarm: swarm.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
