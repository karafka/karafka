# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
