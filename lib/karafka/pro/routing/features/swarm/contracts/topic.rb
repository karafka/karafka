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
          # Namespace for swarm contracts
          module Contracts
            # Contract to validate configuration of the swarm feature
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('topic')
              end

              nested(:swarm) do
                required(:active) { |val| val == true }

                required(:nodes) do |val|
                  val.is_a?(Range) || (
                    val.is_a?(Array) &&
                    val.all? { |id| id.is_a?(Integer) }
                  )
                end
              end

              # Make sure that if range is defined it fits number of nodes (except infinity)
              # As it may be a common error to accidentally define a node that will never be
              # reached
              virtual do |data, errors|
                next unless errors.empty?

                nodes = data[:swarm][:nodes]

                # Defaults
                next if nodes.first.zero? && nodes.include?(Float::INFINITY)

                # If our expectation towards which node should run things matches at least one
                # node, then it's ok
                next if Karafka::App.config.swarm.nodes.times.any? do |node_id|
                  nodes.include?(node_id)
                end

                [[%i[swarm_nodes], :with_non_existent_nodes]]
              end
            end
          end
        end
      end
    end
  end
end
