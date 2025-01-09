# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class DeadLetterQueue < Base
          # Namespace for DLQ contracts
          module Contracts
            # Extended rules for dead letter queue settings
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('topic')
              end

              nested(:dead_letter_queue) do
                # We use strategy based DLQ for every case in Pro
                # For default (when no strategy) a default `max_retries` based strategy is used
                required(:strategy) { |val| val.respond_to?(:call) }
              end

              # Make sure that when we use virtual partitions with DLQ, at least one retry is set
              # We cannot use VP with DLQ without retries as we in order to provide ordering
              # warranties on errors with VP, we need to collapse the VPs concurrency and retry
              # without any indeterministic work
              virtual do |data, errors|
                next unless errors.empty?

                dead_letter_queue = data[:dead_letter_queue]
                virtual_partitions = data[:virtual_partitions]

                next unless dead_letter_queue[:active]
                next unless virtual_partitions[:active]
                next if dead_letter_queue[:max_retries].positive?

                [[%i[dead_letter_queue], :with_virtual_partitions]]
              end
            end
          end
        end
      end
    end
  end
end
