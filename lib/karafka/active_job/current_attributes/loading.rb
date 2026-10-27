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

              validate_cattr_attributes!(cattr_klass, attributes)

              attributes.each do |name, value|
                cattr_klass.public_send("#{name}=", value)
              end
            end

            yield(job)
          ensure
            resetable.each(&:reset)
          end
        end

        private

        # Makes sure that only declared attributes are restored
        #
        # @param cattr_klass [Class] current attributes class
        # @param attributes [Object] attributes extracted from the job payload
        # @raise [ArgumentError] when attributes are not a Hash or contain undeclared attributes
        def validate_cattr_attributes!(cattr_klass, attributes)
          unless attributes.is_a?(Hash)
            raise ArgumentError, "#{cattr_klass} attributes must be a Hash"
          end

          attributes.each_key do |name|
            next if cattr_klass.defaults.key?(name.to_sym)

            raise ArgumentError, "#{cattr_klass} has no attribute #{name}"
          end
        end
      end
    end
  end
end
