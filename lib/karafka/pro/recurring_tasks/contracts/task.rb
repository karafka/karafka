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
    module RecurringTasks
      # Recurring Tasks related contracts
      module Contracts
        # Ensures that task details are as expected
        class Task < ::Karafka::Contracts::Base
          configure do |config|
            config.error_messages = YAML.safe_load(
              File.read(
                File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
              )
            ).fetch('en').fetch('validations').fetch('recurring_tasks')
          end

          # Regexp to ensure all tasks ids are URL safe
          ID_REGEXP = /\A[a-zA-Z0-9_-]{1,}\z/

          required(:id) { |val| val.is_a?(String) && val.match?(ID_REGEXP) }
          required(:cron) { |val| val.is_a?(String) && val.length.positive? }
          required(:enabled) { |val| [true, false].include?(val) }
          required(:changed) { |val| [true, false].include?(val) }
          required(:previous_time) { |val| val.is_a?(Numeric) || val.is_a?(Time) }
        end
      end
    end
  end
end
