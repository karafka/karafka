# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Cleaner
      # Cleaner messages components related enhancements
      module Messages
        # Extensions to the message metadata that allow for granular memory control on a per
        # message basis
        module Metadata
          # @return [Object] deserialized key. By default in the raw string format.
          def key
            cleaned? ? raise(Errors::MessageCleanedError) : super
          end

          # @return [Object] deserialized headers. By default its a hash with keys and payload
          #   being strings
          def headers
            cleaned? ? raise(Errors::MessageCleanedError) : super
          end

          # @return [Boolean] true if the message metadata has been cleaned
          def cleaned?
            raw_headers == false
          end

          # Cleans the headers and key
          def clean!
            self.raw_headers = false
            self.raw_key = false
            @key = nil
            @headers = nil
          end
        end
      end
    end
  end
end
