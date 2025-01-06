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
    # Feature that introduces a granular memory management for each message and messages iterator
    #
    # It allows for better resource allocation by providing an API to clear payload and raw payload
    # from a message after those are no longer needed but before whole messages are freed and
    # removed by Ruby GC.
    #
    # This can be useful when processing bigger batches or bigger messages one after another and
    # wanting not to have all of the data loaded into memory.
    #
    # Can yield significant memory savings (up to 80%).
    module Cleaner
      class << self
        # @param _config [Karafka::Core::Configurable::Node] root node config
        def pre_setup(_config)
          ::Karafka::Messages::Message.prepend(Messages::Message)
          ::Karafka::Messages::Metadata.prepend(Messages::Metadata)
          ::Karafka::Messages::Messages.prepend(Messages::Messages)
        end

        # @param _config [Karafka::Core::Configurable::Node] root node config
        def post_setup(_config)
          true
        end
      end
    end
  end
end
