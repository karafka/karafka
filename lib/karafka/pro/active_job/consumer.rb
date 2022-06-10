# frozen_string_literal: true

module Karafka
  module Pro
    module ActiveJob
      # This Karafka component is a Pro component.
      # All of the commercial components are present in the lib/karafka/pro directory of this
      # repository and their usage requires commercial license agreement.
      #
      # Karafka has also commercial-friendly license, commercial support and commercial components.
      #
      # By sending a pull request to the pro components, you are agreeing to transfer the copyright
      # of your code to Maciej Mensfeld.

      # Pro ActiveJob consumer that is suppose to handle long-running jobs as well as short
      # running jobs
      class Consumer < Karafka::ActiveJob::Consumer
        # Pause for tops 31 years
        MAX_PAUSE_TIME = 1_000_000_000_000

        private_constant :MAX_PAUSE_TIME

        def prepared
          return unless topic.long_running_job?

          # Basically pause forever on the next message
          pause(messages.last.offset + 1, MAX_PAUSE_TIME)
        end

        # Runs ActiveJob jobs processing and handles lrj if needed
        def consume
          super

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
