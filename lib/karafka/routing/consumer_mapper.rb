# frozen_string_literal: true

module Karafka
  module Routing
    # Default consumer mapper that builds consumer ids based on app id and consumer group name
    # Different mapper can be used in case of preexisting consumer names or for applying
    # other naming conventions not compatible wiih Karafkas client_id + consumer name concept
    #
    # @example Mapper for using consumer groups without a client_id prefix
    #   module MyMapper
    #     def self.call(raw_consumer_group_name)
    #       raw_consumer_group_name
    #     end
    #   end
    #
    # @example Mapper for replacing "_" with "." in topic names
    #   module MyMapper
    #     def self.call(raw_consumer_group_name)
    #       [
    #         Dry::Inflector.new.underscore(Karafka::App.config.client_id.to_s),
    #         raw_consumer_group_name
    #       ].join('_').gsub('_', '.')
    #     end
    #   end
    module ConsumerMapper
      # @param raw_consumer_group_name [String, Symbol] string or symbolized consumer group name
      # @return [String] remapped final consumer group name
      def self.call(raw_consumer_group_name)
        client_name = Dry::Inflector.new.underscore(Karafka::App.config.client_id.to_s)
        "#{client_name}_#{raw_consumer_group_name}"
      end
    end
  end
end
