# frozen_string_literal: true

module Karafka
  class Cli
    class Topics < Cli::Base
      # Deletes routing based topics
      class Delete < Base
        # @return [Boolean] true if any topic was deleted, otherwise false
        def call
          any_deleted = false

          declaratives_routing_topics.each do |topic|
            name = topic.name

            if existing_topics_names.include?(name)
              supervised("Deleting topic #{name}") do
                Admin.delete_topic(name)
              end

              puts "#{green('Deleted')} topic #{name}."
              any_deleted = true
            else
              puts "#{yellow('Skipping')} because topic #{name} does not exist."
            end
          end

          any_deleted
        end
      end
    end
  end
end
