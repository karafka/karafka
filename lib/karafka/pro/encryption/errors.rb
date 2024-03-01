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
