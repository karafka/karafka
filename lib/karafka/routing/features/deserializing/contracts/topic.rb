# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Deserializing < Base
        # This feature validation contracts
        module Contracts
          # Basic validation of the Kafka expected config details
          class Topic < Karafka::Contracts::Base
            configure do |config|
              config.error_messages = YAML.safe_load_file(
                File.join(Karafka.gem_root, "config", "locales", "errors.yml")
              ).fetch("en").fetch("validations").fetch("routing").fetch("topic")
            end

            nested :deserializing do
              # Always enabled
              required(:active) { |val| val == true }
              required(:payload) { |val| val.respond_to?(:call) }
              required(:headers) { |val| val.respond_to?(:call) }
              required(:key) { |val| val.respond_to?(:call) }
              required(:parallel) { |val| [true, false].include?(val) }
            end
          end
        end
      end
    end
  end
end
