# frozen_string_literal: true

module Karafka
  module Patches
    module Rdkafka
      # Binding patches that slightly change how rdkafka operates in certain places
      module Bindings
        include ::Rdkafka::Bindings

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
          case code
          when RD_KAFKA_RESP_ERR__ASSIGN_PARTITIONS
            ::Rdkafka::Bindings.rd_kafka_assign(client_ptr, partitions_ptr)
          when RD_KAFKA_RESP_ERR__REVOKE_PARTITIONS
            ::Rdkafka::Bindings.rd_kafka_commit(client_ptr, nil, false)
            ::Rdkafka::Bindings.rd_kafka_assign(client_ptr, FFI::Pointer::NULL)
          else
            ::Rdkafka::Bindings.rd_kafka_assign(client_ptr, FFI::Pointer::NULL)
          end

          opaque = ::Rdkafka::Config.opaques[opaque_ptr.to_i]
          return unless opaque

          tpl = ::Rdkafka::Consumer::TopicPartitionList.from_native_tpl(partitions_ptr).freeze
          consumer = ::Rdkafka::Consumer.new(client_ptr)

          begin
            case code
            when RD_KAFKA_RESP_ERR__ASSIGN_PARTITIONS
              opaque.call_on_partitions_assigned(consumer, tpl)
            when RD_KAFKA_RESP_ERR__REVOKE_PARTITIONS
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
      end
    end
  end
end

::Rdkafka::Bindings.send(
  :remove_const,
  'RebalanceCallback'
)

::Rdkafka::Bindings.const_set(
  'RebalanceCallback',
  Karafka::Patches::Rdkafka::Bindings::RebalanceCallback
)
