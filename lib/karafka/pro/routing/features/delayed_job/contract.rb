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
        class DelayedJob < Base
          # Rules around delayed job settings
          class Contract < Contracts::Base
            configure do |config|
              config.error_messages = YAML.safe_load(
                File.read(
                  File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                )
              ).fetch('en').fetch('validations').fetch('topic')
            end

            nested(:delayed_job) do
              required(:active) { |val| [true, false].include?(val) }
              required(:delay_for) { |val| val.is_a?(Integer) && val >= 0 }
            end

            # Delay should not be less than max wait time because it will anyhow not work well
            virtual do |data, errors|
              next unless errors.empty?

              delayed_job = data[:delayed_job]
              max_wait_time = data[:max_wait_time]

              next unless delayed_job[:active]
              next if delayed_job[:delay_for] >= max_wait_time

              [[%i[delayed_job], :more_than_max_wait_time]]
            end
          end
        end
      end
    end
  end
end
