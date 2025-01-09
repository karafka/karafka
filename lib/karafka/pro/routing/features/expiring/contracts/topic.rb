# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Expiring < Base
          # Namespace for expiring messages contracts
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

              nested(:expiring) do
                required(:active) { |val| [true, false].include?(val) }
                required(:ttl) { |val| val.nil? || (val.is_a?(Integer) && val.positive?) }
              end
            end
          end
        end
      end
    end
  end
end
