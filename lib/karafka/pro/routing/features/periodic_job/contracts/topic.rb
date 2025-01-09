# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class PeriodicJob < Base
          # Namespace for periodics messages contracts
          module Contracts
            # Contract to validate configuration of the periodics feature
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('topic')
              end

              nested(:periodic_job) do
                required(:active) { |val| [true, false].include?(val) }
                required(:interval) { |val| val.is_a?(Integer) && val >= 100 }
                required(:during_pause) { |val| [true, false].include?(val) }
                required(:during_retry) { |val| [true, false].include?(val) }
                required(:materialized) { |val| [true, false].include?(val) }
              end
            end
          end
        end
      end
    end
  end
end
