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
        # @return [String] current state
        attr_accessor :state

        attr_writer :reloads

        # @return [Integer] time epoch when this tracker was started
        attr_reader :started_at

        def initialize
          @daily = Hash.new { |h, k| h[k] = 0 }
          @started_at = Time.now.to_i
          @offsets = { low: -1, high: -1 }
          @state = 'fresh'
          @reloads = 0
        end

        # Tracks offsets of visited messages
        #
        # @param message [Karafka::Messages::Message]
        def offsets(message)
          message_offset = message.offset

          @offsets[:low] = message_offset if @offsets[:low].negative?
          @offsets[:high] = message.offset
        end

        # Accurate (because coming from daily buffer) number of things to schedule daily
        #
        # @param sum [Integer]
        def today=(sum)
          @daily[epoch_to_date(@started_at)] = sum
        end

        # Tracks future message dispatch
        #
        # It is only relevant for future days as for today we use accurate metrics from the daily
        # buffer
        #
        # @param message [Karafka::Messages::Message] schedule message. Should **not** be a
        #   tombstone message. Tombstone messages cancellations are not tracked because it would
        #   drastically increase complexity. For given day we use the accurate counter and for
        #   future days we use estimates.
        def future(message)
          epoch = message.headers['schedule_target_epoch']

          @daily[epoch_to_date(epoch)] += 1
        end

        # @return [Hash] hash with details that we want to expose
        def to_h
          {
            state: @state,
            offsets: @offsets,
            daily: @daily,
            started_at: @started_at,
            reloads: @reloads
          }.freeze
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
