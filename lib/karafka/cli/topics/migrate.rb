# frozen_string_literal: true

module Karafka
  class Cli
    class Topics < Cli::Base
      # Creates missing topics and aligns the partitions count
      class Migrate < Base
        # Runs the migration
        # @return [Boolean] true if there were any changes applied
        # @raise [Karafka::Errors::CommandValidationError] when any topic has configuration
        #   unknown to the cluster. Nothing is applied then.
        def call
          ensure_configs_exist_in_cluster!

          any_changes = false

          if Topics::Create.new.call
            any_changes = true
            wait
          end

          if Topics::Repartition.new.call
            any_changes = true
            wait
          end

          # No need to wait after the last one
          any_changes = true if Topics::Align.new.call

          any_changes
        end
      end
    end
  end
end
