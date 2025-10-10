# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Delaying < Base
          # Namespace for delaying feature contracts
          module Contracts
            # Contract to validate configuration of the expiring feature
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load_file(
                  File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                ).fetch('en').fetch('validations').fetch('routing').fetch('topic')
              end

              nested(:delaying) do
                required(:active) { |val| [true, false].include?(val) }
                required(:delay) { |val| val.nil? || (val.is_a?(Integer) && val.positive?) }
              end
            end
          end
        end
      end
    end
  end
end
