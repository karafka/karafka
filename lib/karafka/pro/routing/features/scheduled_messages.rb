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
        # This feature allows for proxying messages via a special topic that can dispatch them
        # at a later time, hence scheduled messages. Such messages need to have a special format
        # but aside from that they are regular Kafka messages.
        class ScheduledMessages < Base
        end
      end
    end
  end
end
