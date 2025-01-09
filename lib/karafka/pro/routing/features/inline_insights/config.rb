# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class InlineInsights < Base
          # Config of this feature
          Config = Struct.new(
            :active,
            :required,
            keyword_init: true
          ) do
            alias_method :active?, :active
            alias_method :required?, :required
          end
        end
      end
    end
  end
end
