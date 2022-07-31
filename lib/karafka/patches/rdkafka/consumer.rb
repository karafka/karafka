# frozen_string_literal: true

module Karafka
  # Patches to external components
  module Patches
    # Rdkafka related patches
    module Rdkafka
      # Rdkafka::Consumer patches
      module Consumer
        # A method that allows us to get the native kafka producer name
        # @return [String] producer instance name
        # @note We need this to make sure that we allocate proper dispatched events only to
        #   callback listeners that should publish them
        def name
          @name ||= ::Rdkafka::Bindings.rd_kafka_name(@native_kafka)
        end
      end
    end
  end
end

::Rdkafka::Consumer.include ::Karafka::Patches::Rdkafka::Consumer
