# frozen_string_literal: true

module Karafka
  module Declaratives
    # Namespace for declaratives-specific validation contracts
    module Contracts
      # Validates declarative topic configuration. This is the canonical location for declarative
      # topic validation, replacing the routing feature contract.
      class Topic < Karafka::Contracts::Base
        configure do |config|
          config.error_messages = YAML.safe_load_file(
            File.join(Karafka.gem_root, "config", "locales", "errors.yml")
          ).fetch("en").fetch("validations").fetch("routing").fetch("topic")
        end

        nested :declaratives do
          required(:active) { |val| [true, false].include?(val) }
          required(:partitions) { |val| val.is_a?(Integer) && val.positive? }
          required(:replication_factor) { |val| val.is_a?(Integer) && val.positive? }
          required(:details) do |val|
            val.is_a?(Hash) &&
              val.keys.all?(Symbol)
          end
        end
      end
    end
  end
end
