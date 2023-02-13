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

      virtual do |data, errors|
        next unless errors.empty?

        names = data.fetch(:topics).map { |topic| topic[:name] }
        names_hash = names.each_with_object({}) { |n, h| h[n] = true }
        error_occured = false
        names.each do |n|
          # Skip topic names that are not namespaced
          next unless n.chars.find { |c| ['.', '_'].include?(c) }

          if n.chars.include?('.')
            # Check underscore styled topic
            underscored_topic = n.tr('.', '_')
            error_occured = names_hash[underscored_topic] ? true : false
          else
            # Check dot styled topic
            dot_topic = n.tr('_', '.')
            error_occured = names_hash[dot_topic] ? true : false
          end
        end

        next unless error_occured

        [[%i[topics], :topics_namespaced_names_not_unique]]
      end
    end
  end
end
