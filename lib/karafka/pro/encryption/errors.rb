# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Encryption
      # Encryption related errors
      module Errors
        # Base for all the encryption errors
        BaseError = Class.new(::Karafka::Errors::BaseError)

        # Raised when we have encountered encryption key with version we do not have
        PrivateKeyNotFoundError = Class.new(BaseError)

        # Raised when fingerprinting was enabled and payload after encryption did not match it
        FingerprintVerificationError = Class.new(BaseError)
      end
    end
  end
end
