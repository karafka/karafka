# frozen_string_literal: true

module Karafka
  module Helpers
    module Inflector
      ENGINE = Dry::Inflector.new

      @map = Concurrent::Hash.new

      class << self
        def map(element)
          @map[element] ||= ENGINE.underscore(element.to_s).tr('/', '_')
        end

        def map!(attribute)
          @map[attribute]
        end
      end
    end
  end
end
