# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class ParallelSegments < Base
          # Namespace for parallel segments contracts
          module Contracts
            # Contract to validate configuration of the parallel segments feature
            class ConsumerGroup < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('consumer_group')

                nested(:parallel_segments) do
                  required(:active) { |val| [true, false].include?(val) }
                  required(:partitioner) { |val| val.nil? || val.respond_to?(:call) }
                  required(:reducer) { |val| val.respond_to?(:call) }
                  required(:count) { |val| val.is_a?(Integer) && val >= 1 }
                  required(:merge_key) { |val| val.is_a?(String) && val.size >= 1 }
                end

                # When parallel segments are defined, partitioner needs to respond to `#call` and
                # it cannot be nil
                virtual do |data, errors|
                  next unless errors.empty?

                  parallel_segments = data[:parallel_segments]

                  next unless parallel_segments[:active]
                  next if parallel_segments[:partitioner].respond_to?(:call)

                  [[%i[parallel_segments partitioner], :respond_to_call]]
                end
              end
            end
          end
        end
      end
    end
  end
end
