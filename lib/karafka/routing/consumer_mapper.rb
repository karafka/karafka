# frozen_string_literal: true

module Karafka
  module Routing
    # Default consumer mapper that builds consumer ids based on app id and consumer group name
    # Different mapper can be used in case of preexisting consumer names or for applying
    # other naming conventions not compatible with Karafka client_id + consumer name concept
    #
    # @example Mapper for using consumer groups without a client_id prefix
    #   class MyMapper
    #     def call(raw_consumer_group_name)
    #       raw_consumer_group_name
    #     end
    #   end
    class ConsumerMapper
      # @param raw_consumer_group_name [String, Symbol] string or symbolized consumer group name
      # @return [String] remapped final consumer group name
      def call(raw_consumer_group_name)
        "#{Karafka::App.config.client_id}_#{raw_consumer_group_name}"
      end
    end
  end
end
