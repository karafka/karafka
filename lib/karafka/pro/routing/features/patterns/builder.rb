# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class Patterns < Base
          # Expansions for the routing builder
          module Builder
            # Allows us to define the simple routing pattern matching
            #
            # @param regexp_or_name [Symbol, String, Regexp] name of the pattern or regexp for
            #   automatic-based named patterns
            # @param regexp [Regexp, nil] nil if we use auto-generated name based on the regexp or
            #   the regexp if we used named patterns
            # @param block [Proc]
            def pattern(regexp_or_name, regexp = nil, &block)
              consumer_group(default_group_id) do
                pattern(regexp_or_name, regexp, &block)
              end
            end
          end
        end
      end
    end
  end
end
