# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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
          Karafka::Messages::Message.prepend(Messages::Message)
          Karafka::Messages::Metadata.prepend(Messages::Metadata)
          Karafka::Messages::Messages.prepend(Messages::Messages)
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
