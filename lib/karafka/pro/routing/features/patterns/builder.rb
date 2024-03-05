# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
