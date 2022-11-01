# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class DeadLetterQueue < Base
        # Rules around dead letter queue settings
        class Contract < Contracts::Base
          configure do |config|
            config.error_messages = YAML.safe_load(
              File.read(
                File.join(Karafka.gem_root, 'config', 'errors.yml')
              )
            ).fetch('en').fetch('validations').fetch('pro_topic')
          end

          nested :dead_letter_queue do
            required(:active) { |val| [true, false].include?(val) }
            required(:max_retries) { |val| val.is_a?(Integer) && val >= 0 }
          end

          # Validate topic name only if dlq is active
          virtual do |data, errors|
            next unless errors.empty?

            dead_letter_queue = data[:dead_letter_queue]

            next unless dead_letter_queue[:active]

            topic = dead_letter_queue[:topic]

            next if topic.is_a?(String) && Contracts::TOPIC_REGEXP.match?(topic)

            [[%i[dead_letter_queue topic], :format]]
          end
        end
      end
    end
  end
end
