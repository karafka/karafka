# frozen_string_literal: true

module Karafka
  module Patches
    module Rdkafka
      # Binding patches that slightly change how rdkafka operates in certain places
      module Bindings
        include ::Rdkafka::Bindings

        # Alias internally
        RB = ::Rdkafka::Bindings

        class << self
          # Handle assignments on cooperative rebalance
          #
          # @param client_ptr [FFI::Pointer]
          # @param code [Integer]
          # @param partitions_ptr [FFI::Pointer]
          def on_cooperative_rebalance(client_ptr, code, partitions_ptr)
            case code
            when RB::RD_KAFKA_RESP_ERR__ASSIGN_PARTITIONS
              RB.rd_kafka_incremental_assign(client_ptr, partitions_ptr)
            when RB::RD_KAFKA_RESP_ERR__REVOKE_PARTITIONS
              RB.rd_kafka_commit(client_ptr, nil, false)
              RB.rd_kafka_incremental_unassign(client_ptr, partitions_ptr)
            else
              RB.rd_kafka_assign(client_ptr, FFI::Pointer::NULL)
            end
          end

          # Handle assignments on a eager rebalance
          #
          # @param client_ptr [FFI::Pointer]
          # @param code [Integer]
          # @param partitions_ptr [FFI::Pointer]
          def on_eager_rebalance(client_ptr, code, partitions_ptr)
            case code
            when RB::RD_KAFKA_RESP_ERR__ASSIGN_PARTITIONS
              RB.rd_kafka_assign(client_ptr, partitions_ptr)
            when RB::RD_KAFKA_RESP_ERR__REVOKE_PARTITIONS
              RB.rd_kafka_commit(client_ptr, nil, false)
              RB.rd_kafka_assign(client_ptr, FFI::Pointer::NULL)
            else
              RB.rd_kafka_assign(client_ptr, FFI::Pointer::NULL)
            end
          end

          # Trigger Karafka callbacks
          #
          # @param code [Integer]
          # @param opaque [Rdkafka::Opaque]
          # @param consumer [Rdkafka::Consumer]
          # @param tpl [Rdkafka::Consumer::TopicPartitionList]
          def trigger_callbacks(code, opaque, consumer, tpl)
            case code
            when RB::RD_KAFKA_RESP_ERR__ASSIGN_PARTITIONS
              opaque.call_on_partitions_assigned(consumer, tpl)
            when RB::RD_KAFKA_RESP_ERR__REVOKE_PARTITIONS
              opaque.call_on_partitions_revoked(consumer, tpl)
            end
          rescue StandardError => e
            Karafka.monitor.instrument(
              'error.occurred',
              caller: self,
              error: e,
              type: 'connection.client.rebalance_callback.error'
            )
          end
        end

        # This patch changes few things:
        # - it commits offsets (if any) upon partition revocation, so less jobs need to be
        #   reprocessed if they are assigned to a different process
        # - reports callback errors into the errors instrumentation instead of the logger
        # - catches only StandardError instead of Exception as we fully control the directly
        #   executed callbacks
        #
        # @see https://docs.confluent.io/2.0.0/clients/librdkafka/classRdKafka_1_1RebalanceCb.html
        RebalanceCallback = FFI::Function.new(
          :void, %i[pointer int pointer pointer]
        ) do |client_ptr, code, partitions_ptr, opaque_ptr|
          # Patch reference
          pr = ::Karafka::Patches::Rdkafka::Bindings

          if RB.rd_kafka_rebalance_protocol(client_ptr) == 'COOPERATIVE'
            pr.on_cooperative_rebalance(client_ptr, code, partitions_ptr)
          else
            pr.on_eager_rebalance(client_ptr, code, partitions_ptr)
          end

          opaque = ::Rdkafka::Config.opaques[opaque_ptr.to_i]
          return unless opaque

          tpl = ::Rdkafka::Consumer::TopicPartitionList.from_native_tpl(partitions_ptr).freeze
          consumer = ::Rdkafka::Consumer.new(client_ptr)

          pr.trigger_callbacks(code, opaque, consumer, tpl)
        end
      end
    end
  end
end

# We need to replace the original callback with ours.
# At the moment there is no API in rdkafka-ruby to do so
::Rdkafka::Bindings.send(
  :remove_const,
  'RebalanceCallback'
)

::Rdkafka::Bindings.const_set(
  'RebalanceCallback',
  Karafka::Patches::Rdkafka::Bindings::RebalanceCallback
)

::Rdkafka::Bindings.attach_function(
  :rd_kafka_rebalance_protocol,
  %i[pointer],
  :string
)

::Rdkafka::Bindings.attach_function(
  :rd_kafka_incremental_assign,
  %i[pointer pointer],
  :string
)

::Rdkafka::Bindings.attach_function(
  :rd_kafka_incremental_unassign,
  %i[pointer pointer],
  :string
)
