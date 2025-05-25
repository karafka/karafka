# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module RecurringTasks
      # Recurring Tasks related contracts
      module Contracts
        # Makes sure, all the expected config is defined as it should be
        class Config < ::Karafka::Contracts::Base
          configure do |config|
            config.error_messages = YAML.safe_load(
              File.read(
                File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
              )
            ).fetch('en').fetch('validations').fetch('config')
          end

          nested(:recurring_tasks) do
            required(:consumer_class) { |val| val < ::Karafka::BaseConsumer }
            required(:deserializer) { |val| !val.nil? }
            required(:logging) { |val| [true, false].include?(val) }
            # Do not allow to run more often than every 5 seconds
            required(:interval) { |val| val.is_a?(Integer) && val >= 1_000 }
            required(:group_id) do |val|
              val.is_a?(String) && Karafka::Contracts::TOPIC_REGEXP.match?(val)
            end

            nested(:topics) do
              nested(:schedules) do
                required(:name) do |val|
                  val.is_a?(String) && Karafka::Contracts::TOPIC_REGEXP.match?(val)
                end
              end

              nested(:logs) do
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
