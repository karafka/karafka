# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Throttling < Base
          # Namespace for throttling contracts
          module Contracts
            # Rules around throttling settings
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('topic')
              end

              nested(:throttling) do
                required(:active) { |val| [true, false].include?(val) }
                required(:interval) { |val| val.is_a?(Integer) && val.positive? }
                required(:limit) do |val|
                  (val.is_a?(Integer) || val == Float::INFINITY) && val.positive?
                end
              end
            end
          end
        end
      end
    end
  end
end
