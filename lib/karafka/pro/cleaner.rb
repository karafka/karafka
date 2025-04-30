# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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

        # This feature does not need any changes post-fork
        #
        # @param _config [Karafka::Core::Configurable::Node]
        # @param _pre_fork_producer [WaterDrop::Producer]
        def post_fork(_config, _pre_fork_producer)
          true
        end
      end
    end
  end
end
