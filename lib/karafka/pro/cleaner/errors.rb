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
    module Cleaner
      # Cleaner related errors
      module Errors
        # Base for all the clearer errors
        BaseError = Class.new(::Karafka::Errors::BaseError)

        # Raised when trying to deserialize a message that has already been cleaned
        MessageCleanedError = Class.new(BaseError)
      end
    end
  end
end
