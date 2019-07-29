# frozen_string_literal: true

module Karafka
  # Params namespace encapsulating all the logic that is directly related to params handling
  module Params
    # It provides lazy loading not only until the first usage, but also allows us to skip
    # using deserializer until we execute our logic. That way we can operate with
    # heavy-deserialization data without slowing down the whole application.
    class Params < Hash
      # Params attributes that should be available via a method call invocation for Kafka
      # client compatibility.
      # Kafka passes internally Kafka::FetchedMessage object and the ruby-kafka consumer
      # uses those fields via method calls, so in order to be able to pass there our params
      # objects, have to have same api.
      METHOD_ATTRIBUTES = %w[
        create_time
        headers
        is_control_record
        key
        offset
        deserializer
        deserialized
        partition
        receive_time
        topic
        payload
      ].freeze

      private_constant :METHOD_ATTRIBUTES

      METHOD_ATTRIBUTES.each do |attr|
        # Defines a method call accessor to a particular hash field.
        # @note Won't work for complex key names that contain spaces, etc
        # @param key [Symbol] name of a field that we want to retrieve with a method call
        # @example
        #   key_attr_reader :example
        #   params.example #=> 'my example payload'
        define_method(attr) do
          self[attr]
        end
      end

      # @return [Karafka::Params::Params] This method will trigger deserializer execution. If we
      #   decide to retrieve data, deserializer will be executed to get data. Output of that will
      #   be merged to the current object. This object will be also marked as already deserialized,
      #   so we won't deserialize it again.
      def deserialize!
        return self if self['deserialized']

        self['deserialized'] = true
        self['payload'] = deserialize
        self
      end

      private

      # @return [Object] deserialized data
      def deserialize
        Karafka.monitor.instrument('params.params.deserialize', caller: self) do
          self['deserializer'].call(self)
        end
      rescue ::StandardError => e
        Karafka.monitor.instrument('params.params.deserialize.error', caller: self, error: e)
        raise e
      end
    end
  end
end
