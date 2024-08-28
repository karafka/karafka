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
    module ScheduledMessages
      # Tracks basic state and metrics about schedules to be dispatched
      #
      # It provides accurate today dispatch taken from daily buffer and estimates for future days
      class Tracker
        # @return [Hash<String, Integer>]
        attr_reader :daily

        # @return [String] current state
        attr_accessor :state

        def initialize
          @daily = Hash.new { |h, k| h[k] = 0 }
          @created_at = Time.now.to_i
        end

        # Accurate (because coming from daily buffer) number of things to schedule
        #
        # @param sum [Integer]
        def today=(sum)
          @daily[epoch_to_date(@created_at)] = sum
        end

        # Tracks message dispatch
        #
        # It is only relevant for future days as for today we use accurate metrics from the daily
        # buffer
        #
        # @param message [Karafka::Messages::Message] schedule message. Should **not** be a
        #   tombstone message. Tombstone messages cancellations are not tracked because it would
        #   drastically increase complexity. For given day we use the accurate counter and for
        #   future days we use estimates.
        def track(message)
          epoch = message.headers['schedule_target_epoch']

          @daily[epoch_to_date(epoch)] += 1
        end

        private

        # @param epoch [Integer] epoch time
        # @return [String] epoch matching date
        def epoch_to_date(epoch)
          Time.at(epoch).utc.to_date.to_s
        end
      end
    end
  end
end
