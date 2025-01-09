# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
