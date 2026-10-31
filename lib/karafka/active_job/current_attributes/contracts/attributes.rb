# frozen_string_literal: true

module Karafka
  module ActiveJob
    module CurrentAttributes
      # Contracts namespace for current attributes validation logic
      module Contracts
        # Contract for validating the current attributes restored from a job payload
        class Attributes < Karafka::Contracts::Base
          configure do |config|
            config.error_messages = YAML.safe_load_file(
              File.join(Karafka.gem_root, "config", "locales", "errors.yml")
            ).fetch("en").fetch("validations").fetch("current_attributes")
          end

          required(:attributes) { |val| val.is_a?(Hash) }
        end
      end
    end
  end
end
