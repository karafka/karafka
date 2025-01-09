# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Patterns < Base
          # Namespace for patterns feature contracts
          module Contracts
            # Contract to validate configuration of the patterns feature
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('topic')
              end

              nested(:patterns) do
                required(:active) { |val| [true, false].include?(val) }
                required(:type) { |val| %i[matcher discovered regular].include?(val) }
              end
            end
          end
        end
      end
    end
  end
end
