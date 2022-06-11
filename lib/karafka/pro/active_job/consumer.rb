# frozen_string_literal: true

# This Karafka component is a Pro component.
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
      class Consumer < Karafka::ActiveJob::Consumer
        # Pause for tops 31 years
        MAX_PAUSE_TIME = 1_000_000_000_000

        private_constant :MAX_PAUSE_TIME

        # Before we switch to a non-blocking mode, we need to pause this partition forever
        def prepared
          return unless topic.long_running_job?

          # Basically pause forever on the next message (if exists)
          pause(messages.last.offset + 1, MAX_PAUSE_TIME)
        end

        # Runs ActiveJob jobs processing and handles lrj if needed
        def consume
          messages.each do |message|
            ::ActiveJob::Base.execute(
              ::ActiveSupport::JSON.decode(message.raw_payload)
            )

            # If partition was revoked, there won't be anything to mark as consumed
            return if revoked?

            mark_as_consumed(message)

            # If for any reason we've lost this partition, not worth iterating over new messages
            # as they are no longer ours
            return if Karafka::App.stopping?
          end

          return unless topic.long_running_job?

          # Resume processing if it was an lrj
          # If it was lrj  it was paused during the preparation phase, so we need to resume to get
          # new jobs
          resume
        end
      end
    end
  end
end
