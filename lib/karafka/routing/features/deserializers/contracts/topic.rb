# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Deserializers < Base
        # This feature validation contracts
        module Contracts
          # Basic validation of the Kafka expected config details
          class Topic < Karafka::Contracts::Base
            configure do |config|
              config.error_messages = YAML.safe_load(
                File.read(
                  File.join(Karafka.gem_root, 'config', 'locales', 'errors.yml')
                )
              ).fetch('en').fetch('validations').fetch('topic')
            end

            nested :deserializers do
              # Always enabled
              required(:active) { |val| val == true }
              required(:payload) { |val| val.respond_to?(:call) }
              required(:headers) { |val| val.respond_to?(:call) }
              required(:key) { |val| val.respond_to?(:call) }
            end
          end
        end
      end
    end
  end
end
