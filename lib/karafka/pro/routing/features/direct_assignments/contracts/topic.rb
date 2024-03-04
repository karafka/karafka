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
        class DirectAssignments < Base
          # Namespace for direct assignments feature contracts
          module Contracts
            # Contract to validate configuration of the direct assignments topic feature
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('topic')
              end

              nested(:direct_assignments) do
                required(:active) { |val| [true, false].include?(val) }

                required(:partitions) do |val|
                  next true if val == true
                  next false unless val.is_a?(Hash)
                  next false unless val.keys.all? { |part| part.is_a?(Integer) }
                  next false unless val.values.all? { |flag| flag == true }

                  true
                end
              end

              virtual do |data, errors|
                next unless errors.empty?

                direct_assignments = data[:direct_assignments]
                partitions = direct_assignments[:partitions]

                next unless direct_assignments[:active]
                next unless partitions.is_a?(Hash)
                next unless partitions.empty?

                [[%i[direct_assignments], :active_but_empty]]
              end

              # Make sure that when we use swarm, all requested partitions have allocation
              # We cannot assign partitions and then not allocate them in swarm mode
              # If this is the case, they should not be assigned in the first place
              virtual do |data, errors|
                next unless errors.empty?

                direct_assignments = data[:direct_assignments]
                swarm = data[:swarm]

                next unless direct_assignments[:active]
                next unless swarm[:active]

                nodes = swarm[:nodes]

                next unless nodes.is_a?(Hash)
                # Can be true for all partitions assignment and in this case we do not check
                next unless direct_assignments[:partitions].is_a?(Hash)

                direct_partitions = direct_assignments[:partitions].keys
                swarm_partitions = nodes.values.flatten

                next unless swarm_partitions.all? { |partition| partition.is_a?(Integer) }
                next if direct_partitions.sort == swarm_partitions.sort

                # If we assigned more partitions than we distributed in swarm
                if (direct_partitions - swarm_partitions).size.positive?
                  [[%i[direct_assignments], :swarm_not_complete]]
                else
                  [[%i[direct_assignments], :swarm_overbooked]]
                end
              end
            end
          end
        end
      end
    end
  end
end
