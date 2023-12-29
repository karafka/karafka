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
          # Namespace for VP contracts
          module Contracts
            # Rules around virtual partitions
            class Topic < Karafka::Contracts::Base
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
                required(:offset_metadata_strategy) { |val| %i[exact current].include?(val) }
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
            end
          end
        end
      end
    end
  end
end
