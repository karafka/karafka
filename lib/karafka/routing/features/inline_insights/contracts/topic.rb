# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class InlineInsights < Base
        # Inline Insights related contracts namespace
        module Contracts
          # Contract for inline insights topic setup
          class Topic < Karafka::Contracts::Base
            configure do |config|
              config.error_messages = YAML.safe_load_file(
                File.join(Karafka.gem_root, 'config', 'locales', 'errors.yml')
              ).fetch('en').fetch('validations').fetch('routing').fetch('topic')
            end

            nested :inline_insights do
              required(:active) { |val| [true, false].include?(val) }
            end
          end
        end
      end
    end
  end
end
