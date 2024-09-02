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

        names = data.fetch(:topics).map { |topic| topic_unique_key(topic) }

        next if names.size == names.uniq.size

        [[%i[topics], :names_not_unique]]
      end

      # Prevent same topics subscriptions in one CG with different consumer classes
      # This should prevent users from accidentally creating multi-sg one CG setup with weird
      # different consumer usage. If you need to consume same topic twice, use distinct CGs.
      virtual do |data, errors|
        next unless errors.empty?

        topics_consumers = Hash.new { |h, k| h[k] = Set.new }

        data.fetch(:topics).map do |topic|
          topics_consumers[topic[:name]] << topic[:consumer]
        end

        next if topics_consumers.values.map(&:size).all? { |count| count == 1 }

        [[%i[topics], :many_consumers_same_topic]]
      end

      virtual do |data, errors|
        next unless errors.empty?
        next unless ::Karafka::App.config.strict_topics_namespacing

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

      class << self
        # @param topic [Hash] topic config hash
        # @return [String] topic unique key for validators
        def topic_unique_key(topic)
          topic[:name]
        end
      end
    end
  end
end
