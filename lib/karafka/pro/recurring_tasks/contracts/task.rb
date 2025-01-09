# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
