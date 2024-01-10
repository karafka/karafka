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
        class Multiplexing < Base
          # Namespace for multiplexing feature contracts
          module Contracts
            # Validates the subscription group multiplexing setup
            # We validate it on the topic level as subscription groups are not built during the
            # routing as they are pre-run dynamically built.
            #
            # multiplexing attributes are optional since multiplexing may not be enabled
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('topic')
              end

              nested(:subscription_group_details) do
                optional(:multiplexing_min) { |val| val.is_a?(Integer) && val >= 1 }
                optional(:multiplexing_max) { |val| val.is_a?(Integer) && val >= 1 }
                optional(:multiplexing_boot) { |val| val.is_a?(Integer) && val >= 1 }
              end

              # Makes sure min is not more than max
              virtual do |data, errors|
                next unless errors.empty?
                next unless min(data)
                next unless max(data)

                min = min(data)
                max = max(data)

                next if min <= max

                [[%w[subscription_group_details], :multiplexing_min_max_mismatch]]
              end

              # Makes sure that boot is between min and max
              virtual do |data, errors|
                next unless errors.empty?
                next unless min(data)
                next unless max(data)
                next unless boot(data)

                min = min(data)
                max = max(data)
                boot = boot(data)

                next if boot >= min && boot <= max

                [[%w[subscription_group_details], :multiplexing_boot_mismatch]]
              end

              class << self
                # @param data [Hash] topic details
                # @return [Integer, false] min or false if missing
                def min(data)
                  data[:subscription_group_details].fetch(:multiplexing_min, false)
                end

                # @param data [Hash] topic details
                # @return [Integer, false] max or false if missing
                def max(data)
                  data[:subscription_group_details].fetch(:multiplexing_max, false)
                end

                # @param data [Hash] topic details
                # @return [Integer, false] boot or false if missing
                def boot(data)
                  data[:subscription_group_details].fetch(:multiplexing_boot, false)
                end
              end
            end
          end
        end
      end
    end
  end
end
