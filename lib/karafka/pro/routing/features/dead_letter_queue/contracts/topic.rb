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
