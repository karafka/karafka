# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class ManualOffsetManagement < Base
        # This feature validation contracts
        module Contracts
          # Rules around manual offset management settings
          class Topic < Karafka::Contracts::Base
            configure do |config|
              config.error_messages = YAML.safe_load(
                File.read(
                  File.join(Karafka.gem_root, 'config', 'locales', 'errors.yml')
                )
              ).fetch('en').fetch('validations').fetch('topic')
            end

            nested :manual_offset_management do
              required(:active) { |val| [true, false].include?(val) }
            end
          end
        end
      end
    end
  end
end
