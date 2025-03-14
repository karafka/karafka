# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class DeadLetterQueue < Base
        # This feature validation contracts
        module Contracts
          # Rules around dead letter queue settings
          class Topic < Karafka::Contracts::Base
            configure do |config|
              config.error_messages = YAML.safe_load(
                File.read(
                  File.join(Karafka.gem_root, 'config', 'locales', 'errors.yml')
                )
              ).fetch('en').fetch('validations').fetch('topic')
            end

            nested :dead_letter_queue do
              required(:active) { |val| [true, false].include?(val) }
              required(:independent) { |val| [true, false].include?(val) }
              required(:max_retries) { |val| val.is_a?(Integer) && val >= 0 }
              required(:transactional) { |val| [true, false].include?(val) }
              required(:mark_after_dispatch) { |val| [true, false, nil].include?(val) }

              required(:dispatch_method) do |val|
                %i[produce_async produce_sync].include?(val)
              end

              required(:marking_method) do |val|
                %i[mark_as_consumed mark_as_consumed!].include?(val)
              end
            end

            # Validate topic name only if dlq is active
            virtual do |data, errors|
              next unless errors.empty?

              dead_letter_queue = data[:dead_letter_queue]

              next unless dead_letter_queue[:active]

              topic = dead_letter_queue[:topic]
              topic_regexp = ::Karafka::Contracts::TOPIC_REGEXP

              # When topic is set to false, it means we just want to skip dispatch on DLQ
              next if topic == false
              next if topic.is_a?(String) && topic_regexp.match?(topic)
              next if topic == :strategy

              [[%i[dead_letter_queue topic], :format]]
            end
          end
        end
      end
    end
  end
end
