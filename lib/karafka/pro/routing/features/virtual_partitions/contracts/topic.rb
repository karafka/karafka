# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
                required(:reducer) { |val| val.respond_to?(:call) }
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
