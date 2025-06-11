# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Swarm < Base
          module Contracts
            # Special contract that validates prior to starting swarm that each node has
            # at least one assignment.
            #
            # It is special because we cannot run it during routing definitions, because we can
            # only run it when all routes are defined and full context is available.
            #
            # This is why we use it before warmup when everything is expected to be configured.
            class Routing < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('routing')
              end

              # Validates that each node has at least one assignment.
              #
              # @param builder [Karafka::Routing::Builder]
              # @param scope [Array<String>]
              def validate!(builder, scope: [])
                nodes_setup = Hash.new do |h, node_id|
                  h[node_id] = { active: false, node_id: node_id }
                end

                # Initialize nodes in the hash so we can iterate over them
                App.config.swarm.nodes.times { |node_id| nodes_setup[node_id] }
                nodes_setup.freeze

                builder.each do |consumer_group|
                  consumer_group.topics.each do |topic|
                    nodes_setup.each do |node_id, details|
                      next unless topic.active?
                      next unless topic.swarm.nodes.include?(node_id)

                      details[:active] = true
                    end
                  end
                end

                nodes_setup.each_value do |details|
                  super(details, scope: scope)
                end
              end

              virtual do |data, errors|
                next unless errors.empty?
                next if data[:active]

                [[%i[swarm_nodes], :not_used]]
              end
            end
          end
        end
      end
    end
  end
end
