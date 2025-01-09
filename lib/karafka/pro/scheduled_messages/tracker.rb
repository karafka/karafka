# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
