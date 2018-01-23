# frozen_string_literal: true

module Karafka
  module Helpers
    # A helper method that allows us to build methods that try to get a given
    # attribute from its instance value and if it fails, will fallback to
    # the default config or config.kafka value for a given attribute.
    # It is used to simplify the checkings.
    # @note Worth noticing, that the value might be equal to false, so even
    #   then we need to return it. That's why we check for nil?
    # @example Define config retried attribute for start_from_beginning
    # class Test
    #   extend Karafka::Helpers::ConfigRetriever
    #   config_retriever_for :start_from_beginning
    # end
    #
    # Test.new.start_from_beginning #=> false
    # test_instance = Test.new
    # test_instance.start_from_beginning = true
    # test_instance.start_from_beginning #=> true
    module ConfigRetriever
      # Builds proper methods for setting and retrieving (with fallback) given attribute value
      # @param attribute [Symbol] attribute name based on which we will build
      #   accessor with fallback
      def config_retriever_for(attribute)
        attr_writer attribute unless method_defined? :"#{attribute}="

        # Don't redefine if we already have accessor for a given element
        return if method_defined? attribute

        define_method attribute do
          current_value = instance_variable_get(:"@#{attribute}")
          return current_value unless current_value.nil?

          value = if Karafka::App.config.respond_to?(attribute)
                    Karafka::App.config.send(attribute)
                  else
                    Karafka::App.config.kafka.send(attribute)
                  end

          instance_variable_set(:"@#{attribute}", value)
        end
      end
    end
  end
end
