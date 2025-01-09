# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        # Dynamic topics builder feature.
        #
        # Allows you to define patterns in routes that would then automatically subscribe and
        # start consuming new topics.
        #
        # This feature works by injecting a topic that represents a regexp subscription (matcher)
        # that at the same time holds the builder block for full config of a newly detected topic.
        #
        # We inject a virtual topic to hold settings but also to be able to run validations
        # during boot to ensure consistency of the pattern base setup.
        class Patterns < Base
        end
      end
    end
  end
end
