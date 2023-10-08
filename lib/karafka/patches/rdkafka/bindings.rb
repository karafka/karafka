# frozen_string_literal: true

module Karafka
  # Namespace for third-party libraries patches
  module Patches
    # Rdkafka patches specific to Karafka
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
          def on_cooperative_rebalance(client_ptr, code, partitions_ptr, tpl, opaque)
            case code
            when RB::RD_KAFKA_RESP_ERR__ASSIGN_PARTITIONS
              instrumented(
                '',
                caller: self,
                code: code,
                tpl: tpl
              ) { opaque&.call_on_partitions_assign(tpl) }

              RB.rd_kafka_incremental_assign(client_ptr, partitions_ptr)
              opaque.call_on_partitions_assigned(tpl) if opaque
            when RB::RD_KAFKA_RESP_ERR__REVOKE_PARTITIONS
              opaque.call_on_partitions_revoke(tpl) if opaque
              RB.rd_kafka_commit(client_ptr, nil, false)
              RB.rd_kafka_incremental_unassign(client_ptr, partitions_ptr)
              opaque.call_on_partitions_revoked(tpl) if opaque
            else
              RB.rd_kafka_assign(client_ptr, FFI::Pointer::NULL)
            end
          end

          # Handle assignments on a eager rebalance
          #
          # @param client_ptr [FFI::Pointer]
          # @param code [Integer]
          # @param partitions_ptr [FFI::Pointer]
          def on_eager_rebalance(client_ptr, code, partitions_ptr, tpl, opaque)
            case code
            when RB::RD_KAFKA_RESP_ERR__ASSIGN_PARTITIONS
              opaque.call_on_partitions_assign(tpl) if opaque
              RB.rd_kafka_assign(client_ptr, partitions_ptr)
              opaque.call_on_partitions_assigned(tpl) if opaque
            when RB::RD_KAFKA_RESP_ERR__REVOKE_PARTITIONS
              opaque.call_on_partitions_revoke(tpl) if opaque
              RB.rd_kafka_commit(client_ptr, nil, false)
              RB.rd_kafka_assign(client_ptr, FFI::Pointer::NULL)
              opaque.call_on_partitions_revoked(tpl) if opaque
            else
              RB.rd_kafka_assign(client_ptr, FFI::Pointer::NULL)
            end
          end

          # Trigger Karafka callbacks
          #
          # @param code [Integer]
          # @param opaque [Rdkafka::Opaque]
          # @param tpl [Rdkafka::Consumer::TopicPartitionList]
          def trigger_callbacks(code, opaque, tpl)
            Karafka.monitor.instrument(
              'connection.client.rebalance_callback',
              caller: self,
              code: code,
              tpl: tpl
            ) do
              case code
              when RB::RD_KAFKA_RESP_ERR__ASSIGN_PARTITIONS
                opaque.call_on_partitions_assigned(tpl)
              when RB::RD_KAFKA_RESP_ERR__REVOKE_PARTITIONS
                opaque.call_on_partitions_revoked(tpl)
              end
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
          tpl = ::Rdkafka::Consumer::TopicPartitionList.from_native_tpl(partitions_ptr).freeze
          opaque = ::Rdkafka::Config.opaques[opaque_ptr.to_i]

          if RB.rd_kafka_rebalance_protocol(client_ptr) == 'COOPERATIVE'
            pr.on_cooperative_rebalance(client_ptr, code, partitions_ptr, tpl, opaque)
          else
            pr.on_eager_rebalance(client_ptr, code, partitions_ptr, tpl, opaque)
          end

          return unless opaque

          pr.trigger_callbacks(code, opaque, tpl)
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
