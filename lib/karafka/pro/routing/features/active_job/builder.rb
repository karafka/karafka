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
