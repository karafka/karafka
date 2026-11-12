# frozen_string_literal: true

module Karafka
  class Cli
    class Topics < Cli::Base
      # Deletes routing based topics and re-creates them
      class Reset < Base
        # @return [true] since it is a reset, always changes so `true` always
        # @raise [Karafka::Errors::CommandValidationError] when any topic has configuration
        #   unknown to the cluster or one that creating a topic does not accept (a synonym).
        #   Nothing is deleted then.
        def call
          ensure_configs_exist_in_cluster!

          Delete.new.call && wait
          Create.new.call

          true
        end

        private

        # @return [Hash{Karafka::Declaratives::Topic => Hash{String => String}}] declarative
        #   topics with their configs that the cluster does not know. All topics are checked as
        #   ones to be created, as reset re-creates them after deleting.
        def unknown_configs
          @unknown_configs ||= find_unknown_configs(as_new: true)
        end
      end
    end
  end
end
