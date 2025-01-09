# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class ActiveJob < Base
          # Pro ActiveJob builder expansions
          module Builder
            # This method simplifies routes definition for ActiveJob patterns / queues by
            # auto-injecting the consumer class and other things needed
            #
            # @param regexp_or_name [String, Symbol, Regexp] pattern name or regexp to use
            #   auto-generated regexp names
            # @param regexp [Regexp, nil] activejob regexp pattern or nil when regexp is provided
            #   as the first argument
            # @param block [Proc] block that we can use for some extra configuration
            def active_job_pattern(regexp_or_name, regexp = nil, &block)
              pattern(regexp_or_name, regexp) do
                consumer App.config.internal.active_job.consumer_class
                active_job true
                manual_offset_management true

                next unless block

                instance_eval(&block)
              end
            end
          end
        end
      end
    end
  end
end
