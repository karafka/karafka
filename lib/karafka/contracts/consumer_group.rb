# frozen_string_literal: true

module Karafka
  module Contracts
    # Contract for single full route (consumer group + topics) validation.
    class ConsumerGroup < Base
      configure do |config|
        config.error_messages = YAML.safe_load(
          File.read(
            File.join(Karafka.gem_root, 'config', 'locales', 'errors.yml')
          )
        ).fetch('en').fetch('validations').fetch('consumer_group')
      end

      required(:id) { |val| val.is_a?(String) && Contracts::TOPIC_REGEXP.match?(val) }
      required(:topics) { |val| val.is_a?(Array) && !val.empty? }

      virtual do |data, errors|
        next unless errors.empty?

        names = data.fetch(:topics).map { |topic| topic[:name] }

        next if names.size == names.uniq.size

        [[%i[topics], :names_not_unique]]
      end
    end
  end
end
