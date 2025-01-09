# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class OffsetMetadata < Base
          # Namespace for offset metadata feature contracts
          module Contracts
            # Contract to validate configuration of the expiring feature
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('topic')
              end

              nested(:offset_metadata) do
                required(:active) { |val| val == true }
                required(:cache) { |val| [true, false].include?(val) }
                required(:deserializer) { |val| val.respond_to?(:call) }
              end
            end
          end
        end
      end
    end
  end
end
