# frozen_string_literal: true

module Karafka
  module ActiveJob
    module CurrentAttributes
      # Module adding the current attributes persistence into the ActiveJob jobs
      module Persistence
        # Alters the job serialization to inject the current attributes into the json before we
        # send it to Kafka
        #
        # @param job [ActiveJob::Base] job
        def serialize_job(job)
          json = super(job)

          _cattr_klasses.each do |key, cattr_klass_str|
            next if json.key?(key)

            attrs = cattr_klass_str.constantize.attributes

            json[key] = attrs unless attrs.empty?
          end

          json
        end
      end
    end
  end
end
