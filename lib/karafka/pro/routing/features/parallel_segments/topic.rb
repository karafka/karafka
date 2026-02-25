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
    module Routing
      module Features
        class ParallelSegments < Base
          # Parallel segments related expansions to the topic building flow
          module Topic
            # Injects the parallel segments filter as the first filter during building of each of
            # the topics in case parallel segments are enabled.
            #
            # @param args [Object] anything accepted by the topic initializer
            def initialize(*args)
              super

              return unless consumer_group.parallel_segments?

              builder = lambda do |topic, _partition|
                mom = topic.manual_offset_management?

                # We have two filters for mom and non-mom scenario not to mix this logic
                filter_scope = Karafka::Pro::Processing::ParallelSegments::Filters
                filter_class = mom ? filter_scope::Mom : filter_scope::Default

                filter_class.new(
                  segment_id: consumer_group.segment_id,
                  partitioner: consumer_group.parallel_segments.partitioner,
                  reducer: consumer_group.parallel_segments.reducer
                )
              end

              filter(builder)
            end
          end
        end
      end
    end
  end
end
