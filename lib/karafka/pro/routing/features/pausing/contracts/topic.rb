# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
