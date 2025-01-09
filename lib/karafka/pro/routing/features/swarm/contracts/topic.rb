# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
                  next true if val.is_a?(Range)
                  next true if val.is_a?(Array) && val.all? { |id| id.is_a?(Integer) }
                  next false unless val.is_a?(Hash)
                  next false unless val.keys.all? { |id| id.is_a?(Integer) }

                  values = val.values

                  next false unless values.all? { |ps| ps.is_a?(Array) || ps.is_a?(Range) }
                  next true if values.flatten.all? { |part| part.is_a?(Integer) }
                  next true if values.flatten.all? { |part| part.is_a?(Range) }

                  false
                end
              end

              # Make sure that if range is defined it fits number of nodes (except infinity)
              # As it may be a common error to accidentally define a node that will never be
              # reached
              virtual do |data, errors|
                next unless errors.empty?

                nodes = data[:swarm][:nodes]
                # Hash can be used when we use direct assignments. In such cases nodes ids are
                # keys in the hash and values are partitions
                nodes = nodes.keys if nodes.is_a?(Hash)

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
