# frozen_string_literal: true

module Karafka
  module ActiveJob
    module CurrentAttributes
      # Module adding the current attributes persistence into the ActiveJob jobs
      # This module wraps the Dispatcher#serialize_job to inject current attributes
      module Persistence
        # Wraps the Dispatcher#serialize_job to inject current attributes before serialization
        # This allows us to modify the job before it's serialized without modifying ActiveJob::Base
        #
        # @param job [ActiveJob::Base] the original job to serialize
        # @return [String] serialized job payload with current attributes injected
        #
        # @note This method creates a JobWrapper internally and passes it to the parent's
        #   serialize_job method. The wrapper is transparent to the deserializer.
        def serialize_job(job)
          # Get the job hash
          job_hash = job.serialize

          # Inject current attributes
          _cattr_klasses.each do |key, cattr_klass_str|
            next if job_hash.key?(key)

            attrs = cattr_klass_str.constantize.attributes

            job_hash[key] = attrs unless attrs.empty?
          end

          # Wrap the modified hash in a simple object that implements #serialize
          # This avoids modifying the original job instance
          wrapper = JobWrapper.new(job_hash)

          # Pass the wrapper to the deserializer
          super(wrapper)
        end
      end
    end
  end
end
