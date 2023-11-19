# frozen_string_literal: true

module Karafka
  module ActiveJob
    module CurrentAttributes
      # Module expanding the job deserialization to extract current attributes and load them
      # for the time of the job execution
      module Loading
        # @param job_message [Karafka::Messages::Message] message with active job
        def with_deserialized_job(job_message)
          super(job_message) do |job|
            resetable = []

            _cattr_klasses.each do |key, cattr_klass_str|
              next unless job.key?(key)

              attributes = job.delete(key)

              cattr_klass = cattr_klass_str.constantize

              attributes.each do |name, value|
                cattr_klass.public_send("#{name}=", value)
              end

              resetable << cattr_klass
            end

            yield(job)

            resetable.each(&:reset)
          end
        end
      end
    end
  end
end
