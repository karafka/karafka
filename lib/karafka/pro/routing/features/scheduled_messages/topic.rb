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
        class ScheduledMessages < Base
          # Topic extensions to be able to check if given topic is a scheduled messages topic
          # Please note, that this applies to both the schedules topic and logs topic
          module Topic
            # @param active [Boolean] should this topic be considered related to scheduled messages
            def scheduled_messages(active = false)
              @scheduled_messages ||= Config.new(active: active)
            end

            # @return [Boolean] is this an ActiveJob topic
            def scheduled_messages?
              scheduled_messages.active?
            end

            # @return [Hash] topic with all its native configuration options plus scheduled
            # messages namespace settings
            def to_h
              super.merge(
                scheduled_messages: scheduled_messages.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
