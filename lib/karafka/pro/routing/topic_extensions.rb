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
    # Pro routing components
    module Routing
      # Routing extensions that allow to configure some extra PRO routing options
      module TopicExtensions
        # Internal representation of the virtual partitions settings and configuration
        # This allows us to abstract away things in a nice manner
        VirtualPartitions = Struct.new(
          :active,
          :partitioner,
          :concurrency,
          keyword_init: true
        ) { alias active? active }

        class << self
          # @param base [Class] class we extend
          def prepended(base)
            base.attr_accessor :long_running_job
          end
        end

        # @param concurrency [Integer] max number of virtual partitions that can come out of the
        #   single distribution flow. When set to more than the Karafka threading, will create
        #   more work than workers. When less, can ensure we have spare resources to process other
        #   things in parallel.
        # @return [VirtualPartitions] method that allows to set the virtual partitions details
        #   during the routing configuration and then allows to retrieve it
        def virtual_partitions(
          concurrency: Karafka::App.config.concurrency,
          partitioner: nil
        )
          @virtual_partitions ||= VirtualPartitions.new(
            active: !partitioner.nil?,
            concurrency: concurrency,
            partitioner: partitioner
          )
        end

        # @return [Boolean] are virtual partitions enabled for given topic
        def virtual_partitions?
          virtual_partitions.active?
        end

        # @return [Boolean] is a given job on a topic a long-running one
        def long_running_job?
          @long_running_job || false
        end

        # @return [Hash] hash with topic details and the extensions details
        def to_h
          super.merge(
            virtual_partitions: virtual_partitions.to_h
          )
        end
      end
    end
  end
end
