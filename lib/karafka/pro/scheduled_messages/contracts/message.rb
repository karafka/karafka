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
    module ScheduledMessages
      module Contracts
        # Future message expected format.
        #
        # Our envelope always needs to comply with this format, otherwise we won't have enough
        # details to be able to dispatch the message
        class Message < ::Karafka::Contracts::Base
          configure do |config|
            config.error_messages = YAML.safe_load(
              File.read(
                File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
              )
            ).fetch('en').fetch('validations').fetch('scheduled_messages_message')
          end

          # Headers we expect in each message of type "message" that goes to our scheduled messages
          # topic
          EXPECTED_HEADERS = %w[
            schedule_schema_version
            schedule_target_epoch
            schedule_source_type
            schedule_target_topic
          ].freeze

          required(:key) { |val| val.is_a?(String) && val.size.positive? }
          required(:headers) { |val| val.is_a?(Hash) && (val.keys & EXPECTED_HEADERS).size == 4 }

          # Make sure, that schedule_target_epoch is not older than grace period behind us.
          # While this is not ideal verification of scheduling stuff in past, at leats it will
          # prevent user errors when they schedule at 0, etc
          virtual do |data, errors|
            next unless errors.empty?

            epoch_time = data[:headers].fetch('schedule_target_epoch').to_i

            # We allow for small lag as those will be dispatched but we should prevent dispatching
            # in the past in general as often it is a source of errors
            next if epoch_time >= Time.now.to_i - 10

            [[[:headers], :schedule_target_epoch_in_the_past]]
          end
        end
      end
    end
  end
end
