# frozen_string_literal: true

module Karafka
  # Params namespace encapsulating all the logic that is directly related to params handling
  module Params
    # Dsl for Karafka params. We don't provide the params class here as we want to allow users to
    # use either hash (default) or Rails hash with indifferent access as a base for their params
    #
    # We do that because both of them have their own advantages and we don't want to enforce users
    # to handle things differently if they already use any of those
    #
    # It provides lazy loading not only until the first usage, but also allows us to skip
    # using parser until we execute our logic. That way we can operate with
    # heavy-parsing data without slowing down the whole application.
    module Dsl
      # Params keys that are "our" and internal. We use this list for additional backends
      # that somehow operatae on those keys
      SYSTEM_KEYS = %w[
        parser
        value
        partition
        offset
        key
        create_time
        receive_time
        topic
        parsed
      ].freeze

      # Params attributes that should be available via a method call invocation for Kafka
      # client compatibility.
      # Kafka passes internally Kafka::FetchedMessage object and the ruby-kafka consumer
      # uses those fields via method calls, so in order to be able to pass there our params
      # objects, have to have same api.
      METHOD_ATTRIBUTES = %w[
        topic
        partition
        offset
        key
        create_time
        receive_time
      ].freeze

      private_constant :METHOD_ATTRIBUTES

      # Class methods required by params to work
      module ClassMethods
        # We allow building instances only via the #build method

        # @param message [Kafka::FetchedMessage, Hash] message that we get out of Kafka
        #   in case of building params inside main Karafka process in
        #   Karafka::Connection::Consumer, or a hash when we retrieve data that is already parsed
        # @param parser [Class] parser class that we will use to unparse data
        # @return [Karafka::Params::Params] Karafka params object not yet used parser for
        #   retrieving data that we've got from Kafka
        # @example Build params instance from a hash
        #   Karafka::Params::Params.build({ key: 'value' }) #=> params object
        # @example Build params instance from a Kafka::FetchedMessage object
        #   Karafka::Params::Params.build(message) #=> params object
        def build(message, parser)
          instance = new
          instance['parser'] = parser

          # Non kafka fetched message can happen when we interchange data with an
          # additional backend
          if message.is_a?(Kafka::FetchedMessage)
            instance.send(
              :merge!,
              'value' => message.value,
              'partition' => message.partition,
              'offset' => message.offset,
              'key' => message.key,
              'create_time' => message.create_time,
              'receive_time' => Time.now,
              # When we get raw messages, they might have a topic, that was modified by a
              # topic mapper. We need to "reverse" this change and map back to the non-modified
              # format, so our internal flow is not corrupted with the mapping
              'topic' => Karafka::App.config.topic_mapper.incoming(message.topic)
            )
          else
            instance.send(:merge!, message)
          end

          instance
        end
      end

      # @return [Karafka::Params::Params] this will trigger parser execution. If we decide to
      #   retrieve data, parser will be executed to parse data. Output of parsing will be merged
      #   to the current object. This object will be also marked as already parsed, so we won't
      #   parse it again.
      def retrieve!
        return self if self['parsed']
        self['parsed'] = true

        parsed_data = parse(self['value'])
        delete('value')
        merge!(parsed_data)
      end

      # Includes and extends the base params klass with everything that is needed by Karafka to
      #   fully work in any conditions.
      # @param params_klass [Karafka::Params::Params] initialized params class that we will
      #   use for a given Karafka process
      def self.included(params_klass)
        params_klass.extend(Dsl::ClassMethods)

        METHOD_ATTRIBUTES.each do |attr|
          # Defines a method call accessor to a particular hash field.
          # @note Won't work for complex key names that contain spaces, etc
          # @param key [Symbol] name of a field that we want to retrieve with a method call
          # @example
          #   key_attr_reader :example
          #   params.example #=> 'my example value'
          params_klass.send :define_method, attr do
            self[attr]
          end
        end

        params_klass.send :private, :merge!
        params_klass.send :private, :parse
      end

      private

      # Overwritten merge! method - it behaves differently for keys that are the same in our hash
      #  and in a other_hash - it will not replace keys that are the same in our hash
      #  and in the other one. This protects some important Karafka params keys that cannot be
      #  replaced with custom values from incoming Kafka message
      # @param other_hash [Hash] hash that we want to merge into current
      # @return [Karafka::Params::Params] our parameters hash with merged values
      # @example Merge with hash without same keys
      #   new(a: 1, b: 2).merge!(c: 3) #=> { a: 1, b: 2, c: 3 }
      # @example Merge with hash with same keys (symbol based)
      #   new(a: 1).merge!(a: 2) #=> { a: 1 }
      # @example Merge with hash with same keys (string based)
      #   new(a: 1).merge!('a' => 2) #=> { a: 1 }
      # @example Merge with hash with same keys (current string based)
      #   new('a' => 1).merge!(a: 2) #=> { a: 1 }
      def merge!(other_hash)
        super(other_hash) { |_key, base_value, _new_value| base_value }
      end

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
