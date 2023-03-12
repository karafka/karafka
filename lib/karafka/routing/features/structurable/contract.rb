# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Structurable < Base
        # Basic validation of the Kafka expected config details
        class Contract < Contracts::Base
          configure do |config|
            config.error_messages = YAML.safe_load(
              File.read(
                File.join(Karafka.gem_root, 'config', 'locales', 'errors.yml')
              )
            ).fetch('en').fetch('validations').fetch('topic')
          end

          nested :structurable do
            required(:active) { |val| [true, false].include?(val) }
            required(:partitions) { |val| val.is_a?(Integer) && val.positive? }
            required(:replication_factor) { |val| val.is_a?(Integer) && val.positive? }
            required(:details) do |val|
              val.is_a?(Hash) &&
                val.keys.all? { |key| key.is_a?(Symbol) }
            end
          end
        end
      end
    end
  end
end
