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
          messages.each do |message|
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
