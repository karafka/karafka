# frozen_string_literal: true

# This Karafka component is a Pro component.
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    module Contracts
      # Contract for validating correct Pro components setup on a consumer group and topic levels
      class ConsumerGroup < Base
        virtual do |data, errors|
          next unless errors.empty?
          next unless data.key?(:topics)

          fetched_errors = []

          data.fetch(:topics).each do |topic|
            ConsumerGroupTopic.new.call(topic).errors.each do |key, value|
              fetched_errors << [[topic, key].flatten, value]
            end
          end

          fetched_errors
        end
      end
    end
  end
end
