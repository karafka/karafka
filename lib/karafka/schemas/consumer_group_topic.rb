# frozen_string_literal: true

module Karafka
  module Schemas
    # Consumer group topic validation rules
    ConsumerGroupTopic = Dry::Validation.Schema do
      configure do
        # @param value [Object] any object that we want to check if it is a regexp
        # @return [Boolean] true if object is an regexp, otherwise false
        def regexp?(value)
          value.is_a?(::Regexp)
        end
      end

      required(:id).filled(:str?, format?: Karafka::Schemas::TOPIC_REGEXP)
      required(:name).filled { (str? & format?(Karafka::Schemas::TOPIC_REGEXP)) | regexp? }
      required(:backend).filled(included_in?: %i[inline sidekiq])
      required(:consumer).filled
      required(:parser).filled
      required(:max_bytes_per_partition).filled(:int?, gteq?: 0)
      required(:start_from_beginning).filled(:bool?)
      required(:batch_consuming).filled(:bool?)
    end
  end
end
