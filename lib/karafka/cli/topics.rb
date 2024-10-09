# frozen_string_literal: true

module Karafka
  class Cli
    # CLI actions related to Kafka cluster topics management
    class Topics < Base
      include Helpers::Colorize
      include Helpers::ConfigImporter.new(
        kafka_config: %i[kafka]
      )

      desc 'Allows for the topics management'

      option(
        :detailed_exitcode,
        'Exists with 0 when no changes, 1 when error and 2 when changes present or applied',
        TrueClass,
        %w[
          --detailed_exitcode
        ]
      )

      # We exit with 0 if no changes happened
      NO_CHANGES_EXIT_CODE = 0

      # When any changes happened (or could happen) we return 2 because 1 is default when Ruby
      # crashes
      CHANGES_EXIT_CODE = 2

      private_constant :NO_CHANGES_EXIT_CODE, :CHANGES_EXIT_CODE

      # @param action [String] action we want to take
      def call(action = 'missing')
        detailed_exit_code = options.fetch(:detailed_exitcode, false)

        changes = case action
                  when 'create'
                    Topics::Create.new.call
                  when 'delete'
                    Topics::Delete.new.call
                  when 'reset'
                    Topics::Reset.new.call
                  when 'repartition'
                    Topics::Repartition.new.call
                  when 'migrate'
                    Topics::Migrate.new.call
                  when 'align'
                    Topics::Align.new.call
                  when 'plan'
                    Topics::Plan.new.call
                  else
                    raise ::ArgumentError, "Invalid topics action: #{action}"
                  end

        return unless detailed_exit_code

        changes ? exit(NO_CHANGES_EXIT_CODE) : exit(CHANGES_EXIT_CODE)
      end
    end
  end
end
