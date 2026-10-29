# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      module ShareGroups
        class Acknowledgements < Base
          # This feature validation contracts
          module Contracts
            # Validates the acknowledgements settings of a share topic
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load_file(
                  File.join(Karafka.gem_root, "config", "locales", "errors.yml")
                ).fetch("en").fetch("validations").fetch("routing").fetch("topic")
              end

              nested :acknowledgements do
                # Always enabled
                required(:active) { |val| val == true }
                required(:unacknowledged) { |val| %i[release accept reject].include?(val) }
              end
            end
          end
        end
      end
    end
  end
end
