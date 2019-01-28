# frozen_string_literal: true

module Karafka
  module Schemas
    module Predicates
      module Regexp
        include Dry::Logic::Predicates

        predicate(:regexp?) do |value|
          value.is_a?(::Regexp)
        end
      end
    end
  end
end
