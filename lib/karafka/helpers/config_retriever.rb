# frozen_string_literal: true

module Karafka
  module Helpers
    # A helper method that allows us to build methods that try to get a given
    # attribute from its instance value and if it fails, will fallback to
    # the default config or config.kafka value for a given attribute.
    # It is used to simplify the checkings.
    # @note Worth noticing, that the value might be equal to false, so even
    #   then we need to return it. That's why we check for nil?
    module ConfigRetriever
      def config_retriever_for(attribute)
        attr_writer attribute unless method_defined? :"#{attribute}="

        return if method_defined? attribute

        define_method attribute do
          current_value = instance_variable_get(:"@#{attribute}")
          return current_value unless current_value.nil?

          value = if Karafka::App.config.respond_to?(attribute)
                    Karafka::App.config.public_send(attribute)
                  else
                    Karafka::App.config.kafka.public_send(attribute)
                  end

          instance_variable_set(:"@#{attribute}", value)
        end
      end
    end
  end
end
