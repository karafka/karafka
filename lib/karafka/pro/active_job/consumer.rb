# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module ActiveJob
      # Pro ActiveJob consumer that is suppose to handle long-running jobs as well as short
      # running jobs
      #
      # When in LRJ, it will pause a given partition forever and will resume its processing only
      # when all the jobs are done processing.
      #
      # It contains slightly better revocation warranties than the regular blocking consumer as
      # it can stop processing batch of jobs in the middle after the revocation.
      class Consumer < ::Karafka::ActiveJob::Consumer
        # Runs ActiveJob jobs processing and handles lrj if needed
        def consume
          messages.each(clean: true) do |message|
            # If for any reason we've lost this partition, not worth iterating over new messages
            # as they are no longer ours
            break if revoked?

            # We cannot early stop when running virtual partitions because the intermediate state
            # would force us not to commit the offsets. This would cause extensive
            # double-processing
            break if Karafka::App.stopping? && !topic.virtual_partitions?

            consume_job(message)

            # We can always mark because of the virtual offset management that we have in VPs
            mark_as_consumed(message)
          end
        end
      end
    end
  end
end
