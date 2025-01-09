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
                ).fetch('en').fetch('validations').fetch('topic')

                required(:pause_timeout) { |val| val.is_a?(Integer) && val.positive? }
                required(:pause_max_timeout) { |val| val.is_a?(Integer) && val.positive? }
                required(:pause_with_exponential_backoff) { |val| [true, false].include?(val) }

                virtual do |data, errors|
                  next unless errors.empty?

                  pause_timeout = data.fetch(:pause_timeout)
                  pause_max_timeout = data.fetch(:pause_max_timeout)

                  next if pause_timeout <= pause_max_timeout

                  [[%i[pause_timeout], :max_timeout_vs_pause_max_timeout]]
                end
              end
            end
          end
        end
      end
    end
  end
end
