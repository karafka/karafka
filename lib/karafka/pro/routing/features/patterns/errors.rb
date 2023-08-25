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
        class Patterns < Base
          # Patterns specific errors
          module Errors
            # Base class for all the patterns related errors
            BaseError = Class.new(::Karafka::Errors::BaseError)

            # Should not happen. If it happened, it means that there
            # This can happen only if you defined
            #   a pattern that would potentially contradict exclusions or in case the regular
            #   expression matching in librdkafka and Ruby itself would misalign.
            PatternNotMatchedError = Class.new(BaseError)

            # This should never happen. Please open an issue if it does.
            SubscriptionGroupNotFoundError = Class.new(BaseError)
          end
        end
      end
    end
  end
end
