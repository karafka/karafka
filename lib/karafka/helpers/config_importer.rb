# frozen_string_literal: true

module Karafka
  module Helpers
    # Module allowing for configuration injections. By default injects whole app config
    # Allows for granular config injection
    class ConfigImporter < Module
      # @param attributes [Hash<Symbol, Array<Symbol>>] map defining what we want to inject.
      #   The key is the name under which attribute will be visible and the value is the full
      #   path to the attribute
      def initialize(attributes = { config: %i[itself] })
        super()
        @attributes = attributes
      end

      # @param model [Object] object to which we want to add the config fetcher
      def included(model)
        super

        @attributes.each do |name, path|
          model.class_eval <<~RUBY, __FILE__, __LINE__ + 1
            def #{name}
              @#{name} ||= ::Karafka::App.config.#{path.join('.')}
            end
          RUBY
        end
      end

      # @param model [Object] object to which we want to add the config fetcher on a class level
      def extended(model)
        super

        @attributes.each do |name, path|
          model.class_eval <<~RUBY, __FILE__, __LINE__ + 1
            def self.#{name}
              @#{name} ||= ::Karafka::App.config.#{path.join('.')}
            end
          RUBY
        end
      end
    end
  end
end
