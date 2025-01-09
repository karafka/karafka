# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module ScheduledMessages
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

          nested(:scheduled_messages) do
            required(:consumer_class) { |val| val < ::Karafka::BaseConsumer }

            # Do not allow to run more often than every second
            required(:interval) { |val| val.is_a?(Integer) && val >= 1_000 }

            required(:flush_batch_size) { |val| val.is_a?(Integer) && val.positive? }

            required(:dispatcher_class) { |val| !val.nil? }

            required(:group_id) do |val|
              val.is_a?(String) && Karafka::Contracts::TOPIC_REGEXP.match?(val)
            end

            required(:states_postfix) do |val|
              val.is_a?(String) && Karafka::Contracts::TOPIC_REGEXP.match?(val)
            end

            nested(:deserializers) do
              required(:headers) { |val| !val.nil? }
              required(:payload) { |val| !val.nil? }
            end
          end
        end
      end
    end
  end
end
