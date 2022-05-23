# frozen_string_literal: true

module Karafka
  module Connection
    # Partitions pauses management abstraction layer.
    # It aggregates all the pauses for all the partitions that we're working with.
    class PausesManager
      # @return [Karafka::Connection::PausesManager] pauses manager
      def initialize
        @pauses = Hash.new do |h, k|
          h[k] = {}
        end
      end

      # Creates or fetches pause tracker of a given topic partition.
      #
      # @param topic [String] topic name
      # @param partition [Integer] partition number
      # @return [Karafka::TimeTrackers::Pause] pause tracker instance
      def fetch(topic, partition)
        @pauses[topic][partition] ||= TimeTrackers::Pause.new(
          timeout: Karafka::App.config.pause_timeout,
          max_timeout: Karafka::App.config.pause_max_timeout,
          exponential_backoff: Karafka::App.config.pause_with_exponential_backoff
        )
      end

      # Resumes processing of partitions for which pause time has ended.
      #
      # @yieldparam [String] topic name
      # @yieldparam [Integer] partition number
      def resume
        @pauses.each do |topic, partitions|
          partitions.each do |partition, pause|
            next unless pause.paused?
            next unless pause.expired?

            pause.resume

            yield(topic, partition)
          end
        end
      end
    end
  end
end
