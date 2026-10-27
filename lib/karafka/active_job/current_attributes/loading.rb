# frozen_string_literal: true

module Karafka
  module ActiveJob
    module CurrentAttributes
      # Module expanding the job deserialization to extract current attributes and load them
      # for the time of the job execution
      module Loading
        # @param job_message [Karafka::Messages::Message] message with active job
        def with_deserialized_job(job_message)
          super do |job|
            resetable = []

            _cattr_klasses.each do |key, cattr_klass_str|
              next unless job.key?(key)

              attributes = job.delete(key)

              cattr_klass = cattr_klass_str.constantize

              # Registered before any write, so values set before a failing one are reset as well
              resetable << cattr_klass

              unless attributes.is_a?(Hash)
                raise ArgumentError, "#{cattr_klass} attributes must be a Hash"
              end

              attributes.each do |name, value|
                setter = "#{name}="

                # Instance writers only, so class level ones (like `defaults=`) cannot be called
                unless cattr_klass.method_defined?(setter)
                  raise ArgumentError, "#{cattr_klass} has no attribute #{name}"
                end

                cattr_klass.public_send(setter, value)
              end
            end

            yield(job)
          ensure
            resetable.each(&:reset)
          end
        end
      end
    end
  end
end
