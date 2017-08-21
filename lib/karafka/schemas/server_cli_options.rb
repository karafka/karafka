# frozen_string_literal: true

module Karafka
  module Schemas
    ServerCliOptions = Dry::Validation.Schema do
      configure do
        option :topics

        def self.messages
          super.merge(
            en: {
              errors: {
                topics_inclusion: 'Unknown topics that don\'t match any from the routing.',
                pid_existence: 'Pidfile already exists.'
              }
            }
          )
        end
      end

      optional(:pid).filled(:str?)
      optional(:daemon).filled(:bool?)
      optional(:topics).filled(:array?)

      validate(topics_inclusion: :topics) do |topics|
        topics.nil? ? true : \
          (topics - Karafka::App.consumer_groups.map(&:topics).flatten.map(&:name)).empty?
      end

      validate(pid_existence: :pid) do |pid|
        pid ? !File.exist?(pid) : true
      end
    end
  end
end
