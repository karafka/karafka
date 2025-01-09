# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Patterns < Base
          # Namespace for patterns related contracts
          module Contracts
            # Contract used to validate pattern data
            class Pattern < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('pattern')

                required(:regexp) { |val| val.is_a?(Regexp) }

                required(:regexp_string) do |val|
                  val.is_a?(String) && val.start_with?('^') && val.size >= 2
                end

                required(:name) do |val|
                  val.is_a?(String) && Karafka::Contracts::TOPIC_REGEXP.match?(val)
                end
              end
            end
          end
        end
      end
    end
  end
end
