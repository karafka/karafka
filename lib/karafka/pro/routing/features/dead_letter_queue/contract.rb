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
          # Extended rules for dead letter queue settings
          class Contract < Contracts::Base
            configure do |config|
              config.error_messages = YAML.safe_load(
                File.read(
                  File.join(Karafka.gem_root, 'config', 'errors.yml')
                )
              ).fetch('en').fetch('validations').fetch('pro_topic')
            end

            # Make sure that we don't use DLQ with VP
            # Using those two would cause many issues because the offset within VP is not
            # manageable so in scenarios where we would fail on the last message, we would move by
            # one and try again and fail, and move by one and try again and fail and so on...
            virtual do |data, errors|
              next unless errors.empty?

              dead_letter_queue = data[:dead_letter_queue]
              virtual_partitions = data[:virtual_partitions]

              next unless dead_letter_queue[:active]
              next unless virtual_partitions[:active]

              [[%i[dead_letter_queue], :not_with_virtual_partitions]]
            end
          end
        end
      end
    end
  end
end
