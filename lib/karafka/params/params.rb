# frozen_string_literal: true

module Karafka
  # Params namespace encapsulating all the logic that is directly related to params handling
  module Params
    # It provides lazy loading not only until the first usage, but also allows us to skip
    # using parser until we execute our logic. That way we can operate with
    # heavy-parsing data without slowing down the whole application.
    class Params < Hash
      # Params attributes that should be available via a method call invocation for Kafka
      # client compatibility.
      # Kafka passes internally Kafka::FetchedMessage object and the ruby-kafka consumer
      # uses those fields via method calls, so in order to be able to pass there our params
      # objects, have to have same api.
      METHOD_ATTRIBUTES = %w[
        parser
        value
        partition
        offset
        key
        create_time
        receive_time
        topic
        parsed
        headers
      ].freeze

      private_constant :METHOD_ATTRIBUTES

      METHOD_ATTRIBUTES.each do |attr|
        # Defines a method call accessor to a particular hash field.
        # @note Won't work for complex key names that contain spaces, etc
        # @param key [Symbol] name of a field that we want to retrieve with a method call
        # @example
        #   key_attr_reader :example
        #   params.example #=> 'my example value'
        define_method(attr) do
          self[attr]
        end
      end

      # @return [Karafka::Params::Params] This method will trigger parser execution. If we decide
      #   to retrieve data, parser will be executed to parse data. Output of parsing will be merged
      #   to the current object. This object will be also marked as already parsed, so we won't
      #   parse it again.
      def parse!
        return self if self['parsed']
        self['parsed'] = true
        self['value'] = parse(self['value'])
        self
      end

      private

      # @param value [String] Raw data that we want to parse using consumer parser
      # @note If something goes wrong, it will return raw data in a hash with a message key
      # @return [Hash] parsed data or a hash with message key containing raw data if something
      #   went wrong during parsing
      def parse(value)
        Karafka.monitor.instrument('params.params.parse', caller: self) do
          self['parser'].parse(value)
        end
      rescue ::Karafka::Errors::ParserError => e
        Karafka.monitor.instrument('params.params.parse.error', caller: self, error: e)
        raise e
      end
    end
  end
end
