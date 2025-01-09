# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class AdaptiveIterator < Base
          # Namespace for adaptive iterator contracts
          module Contracts
            # Contract to validate configuration of the adaptive iterator feature
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('topic')
              end

              nested(:adaptive_iterator) do
                required(:active) { |val| [true, false].include?(val) }
                required(:safety_margin) { |val| val.is_a?(Integer) && val.positive? && val < 100 }
                required(:clean_after_yielding) { |val| [true, false].include?(val) }

                required(:marking_method) do |val|
                  %i[mark_as_consumed mark_as_consumed!].include?(val)
                end
              end

              # Since adaptive iterator uses `#seek` and can break processing in the middle, we
              # cannot use it with virtual partitions that can process data in a distributed
              # manner
              virtual do |data, errors|
                next unless errors.empty?

                adaptive_iterator = data[:adaptive_iterator]
                virtual_partitions = data[:virtual_partitions]

                next unless adaptive_iterator[:active]
                next unless virtual_partitions[:active]

                [[%i[adaptive_iterator], :with_virtual_partitions]]
              end

              # There is no point of using the adaptive iterator with LRJ because of how LRJ works
              virtual do |data, errors|
                next unless errors.empty?

                adaptive_iterator = data[:adaptive_iterator]
                long_running_jobs = data[:long_running_job]

                next unless adaptive_iterator[:active]
                next unless long_running_jobs[:active]

                [[%i[adaptive_iterator], :with_long_running_job]]
              end
            end
          end
        end
      end
    end
  end
end
