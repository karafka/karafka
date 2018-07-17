# frozen_string_literal: true

module Karafka
  module Helpers
    # Inflector provides inflection for the whole Karafka framework with additional inflection
    # caching (due to the fact, that Dry::Inflector is slow)
    module Inflector
      # What inflection engine do we want to use
      ENGINE = Dry::Inflector.new

      @map = Concurrent::Hash.new

      private_constant :ENGINE

      class << self
        # @param string [String] string that we want to convert to our underscore format
        # @return [String] inflected string
        # @example
        #   Karafka::Helpers::Inflector.map('Module/ControllerName') #=> 'module_controller_name'
        def map(string)
          @map[string] ||= ENGINE.underscore(string).tr('/', '_')
        end
      end
    end
  end
end
