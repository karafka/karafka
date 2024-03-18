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
      # @param action [String] action we want to take
      def call(action = 'missing')
        case action
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
      end
    end
  end
end
