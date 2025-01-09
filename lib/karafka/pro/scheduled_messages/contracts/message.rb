# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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

          # Headers we expect in each message of type "schedule" that goes to our scheduled
          # messages topic
          EXPECTED_SCHEDULE_HEADERS = %w[
            schedule_schema_version
            schedule_target_epoch
            schedule_source_type
            schedule_target_topic
          ].freeze

          # Headers we expect in each message of type "cancel"
          EXPECTED_CANCEL_HEADERS = %w[
            schedule_schema_version
            schedule_source_type
          ].freeze

          required(:key) { |val| val.is_a?(String) && val.size.positive? }

          # Ensure that schedule has all correct keys and that others have other related data
          required(:headers) do |val|
            next false unless val.is_a?(Hash)

            if val['schedule_source_type'] == 'message'
              (val.keys & EXPECTED_SCHEDULE_HEADERS).size >= 4
            else
              (val.keys & EXPECTED_CANCEL_HEADERS).size >= 2
            end
          end

          # Make sure, that schedule_target_epoch is not older than grace period behind us.
          # While this is not ideal verification of scheduling stuff in past, at leats it will
          # prevent user errors when they schedule at 0, etc
          virtual do |data, errors|
            next unless errors.empty?

            # Validate epoch only for schedules
            next unless data[:headers]['schedule_source_type'] == 'schedule'

            epoch_time = data[:headers].fetch('schedule_target_epoch').to_i

            # We allow for small lag as those will be dispatched but we should prevent dispatching
            # in the past in general as often it is a source of errors
            next if epoch_time >= Time.now.to_i - 10

            [[[:headers], :schedule_target_epoch_in_the_past]]
          end

          # Makes sure, that the target envelope topic we dispatch to is a scheduled messages topic
          virtual do |data, errors|
            next unless errors.empty?

            scheduled_topics = Karafka::App
                               .routes
                               .flat_map(&:topics)
                               .flat_map(&:to_a)
                               .select(&:scheduled_messages?)
                               .map(&:name)

            next if scheduled_topics.include?(data[:topic].to_s)

            [[[:topic], :not_a_scheduled_messages_topic]]
          end
        end
      end
    end
  end
end
