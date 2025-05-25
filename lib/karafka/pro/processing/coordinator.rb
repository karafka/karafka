# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      # Pro coordinator that provides extra orchestration methods useful for parallel processing
      # within the same partition
      class Coordinator < ::Karafka::Processing::Coordinator
        extend Forwardable
        include Helpers::ConfigImporter.new(
          errors_tracker_class: %i[internal processing errors_tracker_class]
        )

        def_delegators :@collapser, :collapsed?, :collapse_until!

        attr_reader :filter, :virtual_offset_manager, :shared_mutex, :errors_tracker

        # @param args [Object] anything the base coordinator accepts
        def initialize(*args)
          super

          @executed = []
          @errors_tracker = errors_tracker_class.new(topic, partition)
          @flow_mutex = Mutex.new
          # Lock for user code synchronization
          # We do not want to mix coordinator lock with the user lock not to create cases where
          # user imposed lock would lock the internal operations of Karafka
          # This shared lock can be used by the end user as it is not used internally by the
          # framework and can be used for user-facing locking
          @shared_mutex = Mutex.new
          @collapser = Collapser.new
          @filter = Coordinators::FiltersApplier.new(self)

          return unless topic.virtual_partitions?

          @virtual_offset_manager = Coordinators::VirtualOffsetManager.new(
            topic.name,
            partition,
            topic.virtual_partitions.offset_metadata_strategy
          )

          # We register our own "internal" filter to support filtering of messages that were marked
          # as consumed virtually
          @filter.filters << Filters::VirtualLimiter.new(
            @virtual_offset_manager,
            @collapser
          )
        end

        # Starts the coordination process
        # @param messages [Array<Karafka::Messages::Message>] messages for which processing we are
        #   going to coordinate.
        def start(messages)
          super

          @collapser.refresh!(messages.first.offset)

          @filter.apply!(messages)

          # Do not clear coordinator errors storage when we are retrying, so we can reference the
          # errors that have happened during recovery. This can be useful for implementing custom
          # flows. There can be more errors than one when running with virtual partitions so we
          # need to make sure we collect them all. Under collapse when we reference a given
          # consumer we should be able to get all the errors and not just first/last.
          #
          # @note We use zero as the attempt mark because we are not "yet" in the attempt 1
          @errors_tracker.clear if attempt.zero?
          @executed.clear

          # We keep the old processed offsets until the collapsing is done and regular processing
          # with virtualization is restored
          @virtual_offset_manager.clear if topic.virtual_partitions? && !collapsed?

          @last_message = messages.last
        end

        # Sets the consumer failure status and additionally starts the collapse until
        #
        # @param consumer [Karafka::BaseConsumer] consumer that failed
        # @param error [StandardError] error from the failure
        def failure!(consumer, error)
          super
          @errors_tracker << error
          collapse_until!(@last_message.offset + 1)
        end

        # @return [Boolean] did any of the filters apply any logic that would cause use to run
        #   the filtering flow
        def filtered?
          @filter.applied?
        end

        # @return [Boolean] is the coordinated work finished or not
        # @note Used only in the consume operation context
        def finished?
          @running_jobs[:consume].zero?
        end

        # Runs synchronized code once for a collective of virtual partitions prior to work being
        # enqueued
        def on_enqueued
          @flow_mutex.synchronize do
            return unless executable?(:on_enqueued)

            yield(@last_message)
          end
        end

        # Runs given code only once per all the coordinated jobs upon starting first of them
        def on_started
          @flow_mutex.synchronize do
            return unless executable?(:on_started)

            yield(@last_message)
          end
        end

        # Runs given code once when all the work that is suppose to be coordinated is finished
        # It runs once per all the coordinated jobs and should be used to run any type of post
        # jobs coordination processing execution
        def on_finished
          @flow_mutex.synchronize do
            return unless finished?
            return unless executable?(:on_finished)

            yield(@last_message)
          end
        end

        # Runs once after a partition is revoked
        def on_revoked
          @flow_mutex.synchronize do
            return unless executable?(:on_revoked)

            yield(@last_message)
          end
        end

        # @param interval [Integer] milliseconds of activity
        # @return [Boolean] was this partition in activity within last `interval` milliseconds
        # @note Will return true also if currently active
        def active_within?(interval)
          # its always active if there's any job related to this coordinator that is still
          # enqueued or running
          return true if @running_jobs.values.any?(:positive?)

          # Otherwise we check last time any job of this coordinator was active
          @changed_at + interval > monotonic_now
        end

        private

        # Checks if given action is executable once. If it is and true is returned, this method
        # will return false next time it is used.
        #
        # @param action [Symbol] what action we want to perform
        # @return [Boolean] true if we can
        # @note This method needs to run behind a mutex.
        def executable?(action)
          return false if @executed.include?(action)

          @executed << action

          true
        end
      end
    end
  end
end
