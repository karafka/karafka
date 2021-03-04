# frozen_string_literal: true

module Karafka
  module Processing
    class Worker
      def initialize(queue)
        @queue = queue
        @thread = Thread.new { loop { break unless process } }
      end

      def join
        @thread.join
      end

      private

      def process
        job = @queue.pop

        if job
          job.call
          true
        else
          false
        end
      ensure
        @queue.complete(job) if job
        Thread.pass
      end
    end
  end
end
