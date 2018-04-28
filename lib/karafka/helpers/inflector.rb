# frozen_string_literal: true

module Karafka
  module Helpers
    module Inflector
      ENGINE = Dry::Inflector.new

      def self.underscore(element)
        ENGINE.underscore(element.to_s).tr('/', '_')
      end
    end
  end
end
