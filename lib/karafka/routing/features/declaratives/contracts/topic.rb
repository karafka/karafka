# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Declaratives < Base
        # This feature validation contracts
        module Contracts
          # Basic validation of the Kafka expected config details
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
  end
end
