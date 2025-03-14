# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
