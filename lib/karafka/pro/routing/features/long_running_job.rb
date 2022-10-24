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
    # Namespace for Pro routing enhancements
    module Routing
      # Namespace for additional Pro features
      module Features
        # Long-Running Jobs feature config and DSL namespace.
        #
        # Long-Running Jobs allow you to run Karafka jobs beyond `max.poll.interval.ms`
        class LongRunningJob < Base
        end
      end
    end
  end
end
