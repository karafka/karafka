# frozen_string_literal: true

module Karafka
  module ActiveJob
    module CurrentAttributes
      # Simple wrapper that presents a job hash with current attributes injected.
      #
      # This wrapper exists to pass a modified job hash to the deserializer without
      # modifying the original ActiveJob::Base instance. We cannot modify the job instance
      # directly because:
      #
      # 1. Thread safety: Modifying job instances with singleton methods could cause
      #    concurrency issues in multi-threaded environments
      # 2. Rails ownership: ActiveJob::Base is a Rails class we don't control, and
      #    monkey-patching it could break with Rails updates
      # 3. Side effects: Modifying the job instance could affect other parts of the
      #    application that use the same job object
      #
      # The wrapper implements only the #serialize method that the Deserializer expects,
      # returning our pre-computed hash with current attributes already injected.
      #
      # @example Using JobWrapper with a modified job hash
      #   job_hash = {
      #     'job_class' => 'MyJob',
      #     'arguments' => [1, 2, 3],
      #     'cattr_0' => { 'user_id' => 123 }
      #   }
      #   wrapper = JobWrapper.new(job_hash)
      #   wrapper.serialize # => returns the job_hash
      class JobWrapper
        # @param job_hash [Hash] the job hash with current attributes already injected
        def initialize(job_hash)
          @job_hash = job_hash
        end

        # Returns the job hash with current attributes injected
        #
        # @return [Hash] the job hash with current attributes injected
        def serialize
          @job_hash
        end
      end
    end
  end
end
