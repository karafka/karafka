# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Pausing < Base
          # Namespace for pausing feature
          module Contracts
            # Contract to make sure, that the pause settings on a per topic basis are as expected
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('routing').fetch('topic')

                # Validate the nested pausing configuration
                # Both old setters and new pause() method update the pausing config,
                # so we only need to validate this one format
                nested :pausing do
                  required(:active) { |val| [true, false].include?(val) }
                  required(:timeout) { |val| val.is_a?(Integer) && val.positive? }
                  required(:max_timeout) { |val| val.is_a?(Integer) && val.positive? }
                  required(:with_exponential_backoff) { |val| [true, false].include?(val) }
                end

                # Validate that timeout <= max_timeout
                virtual do |data, errors|
                  next unless errors.empty?

                  pausing = data.fetch(:pausing)
                  timeout = pausing.fetch(:timeout)
                  max_timeout = pausing.fetch(:max_timeout)

                  next if timeout <= max_timeout

                  [[%i[pausing timeout], :max_timeout_vs_pause_max_timeout]]
                end
              end
            end
          end
        end
      end
    end
  end
end
