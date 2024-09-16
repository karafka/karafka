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
        # Feature that pro-actively monitors remaining time until max poll interval ms and
        # cost of processing of each message in a batch. When there is no more time to process
        # more messages from the batch, it will seek back so we do not reach max poll interval.
        # It can be useful when we reach this once in a while. For a constant long-running jobs,
        # please use the Long-Running Jobs feature instead.
        #
        # It also provides some wrapping over typical operations users do, like stopping if
        # revoked, auto-marking, etc
        class AdaptiveIterator < Base
        end
      end
    end
  end
end
