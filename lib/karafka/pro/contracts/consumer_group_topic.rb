# frozen_string_literal: true

# This Karafka component is a Pro component.
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    module Contracts
      # Contract for validating correct Pro components setup on a topic levels
      class ConsumerGroupTopic < Base
        configure do |config|
          config.error_messages = YAML.safe_load(
            File.read(
              File.join(Karafka.gem_root, 'config', 'errors.yml')
            )
          ).fetch('en').fetch('validations').fetch('pro_consumer_group_topic')
        end

        nested(:virtual_partitions) do
          required(:active) { |val| [true, false].include?(val) }
          required(:partitioner) { |val| val.nil? || val.respond_to?(:call) }
          required(:concurrency) { |val| val.is_a?(Integer) && val >= 1 }
        end

        virtual do |data, errors|
          next unless errors.empty?
          next if data[:consumer] < Karafka::Pro::BaseConsumer

          [[%i[consumer], :consumer_format]]
        end

        # When virtual partitions are defined, partitioner needs to respond to `#call` and it
        # cannot be nil
        virtual do |data, errors|
          next unless errors.empty?

          virtual_partitions = data[:virtual_partitions]

          next unless virtual_partitions[:active]
          next if virtual_partitions[:partitioner].respond_to?(:call)

          [[%i[virtual_partitions partitioner], :respond_to_call]]
        end
      end
    end
  end
end
