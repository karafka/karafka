# frozen_string_literal: true

module Karafka
  module Contracts
    # Contract for single full route (consumer group + topics) validation.
    class ConsumerGroup < Base
      configure do |config|
        config.error_messages = YAML.safe_load(
          File.read(
            File.join(Karafka.gem_root, 'config', 'errors.yml')
          )
        ).fetch('en').fetch('validations').fetch('consumer_group')
      end

      required(:id) { |id| id.is_a?(String) && Contracts::TOPIC_REGEXP.match?(id) }
      required(:topics) { |topics| topics.is_a?(Array) && !topics.empty? }

      virtual do |data, errors|
        next unless errors.empty?

        names = data.fetch(:topics).map { |topic| topic[:name] }

        next if names.size == names.uniq.size

        [[%i[topics], :names_not_unique]]
      end

      virtual do |data, errors|
        next unless errors.empty?

        fetched_errors = []

        data.fetch(:topics).each do |topic|
          ConsumerGroupTopic.new.call(topic).errors.each do |key, value|
            fetched_errors << [[topic, key].flatten, value]
          end
        end

        fetched_errors
      end
    end
  end
end
