# frozen_string_literal: true

# This Karafka component is a Pro component.
# All of the commercial components are present in the lib/karafka/pro directory of this repository
# and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    module ActiveJob
      # Contract for validating the options that can be altered with `#karafka_options` per job
      # class that works with Pro features.
      class JobOptionsContract < ::Karafka::ActiveJob::JobOptionsContract
        # Dry types
        Types = include Dry.Types()

        params do
          optional(:partitioner).value(Types.Interface(:call))
        end
      end
    end
  end
end
