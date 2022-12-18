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
        class VirtualPartitions < Base
          # Rules around virtual partitions
          class Contract < Contracts::Base
            configure do |config|
              config.error_messages = YAML.safe_load(
                File.read(
                  File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                )
              ).fetch('en').fetch('validations').fetch('topic')
            end

            nested(:virtual_partitions) do
              required(:active) { |val| [true, false].include?(val) }
              required(:partitioner) { |val| val.nil? || val.respond_to?(:call) }
              required(:max_partitions) { |val| val.is_a?(Integer) && val >= 1 }
            end

            # When virtual partitions are defined, partitioner needs to respond to `#call` and it
            # cannot be nil
            virtual do |data, errors|
              next unless errors.empty?

              virtual_partitions = data[:virtual_partitions]

              next unless virtual_partitions[:active]
              next if virtual_partitions[:partitioner].respond_to?(:call)

              [[%i[virtual_partitions partitioner], :respond_to_call]]
            end

            # Make sure that manual offset management is not used together with Virtual Partitions
            # This would not make any sense as there would be edge cases related to skipping
            # messages even if there were errors.
            virtual do |data, errors|
              next unless errors.empty?

              virtual_partitions = data[:virtual_partitions]
              manual_offset_management = data[:manual_offset_management]
              active_job = data[:active_job]

              next unless virtual_partitions[:active]
              next unless manual_offset_management[:active]
              next if active_job[:active]

              [[%i[manual_offset_management], :not_with_virtual_partitions]]
            end
          end
        end
      end
    end
  end
end
