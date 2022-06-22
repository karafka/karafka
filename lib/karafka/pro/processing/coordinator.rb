# frozen_string_literal: true

module Karafka
  module Pro
    module Processing
      # Pro coordinator that provides extra orchestration methods useful for parallel processing
      # within the same partition
      class Coordinator
        def initialize(pause_tracker)
        end

        def finished?
          @mutex.synchronize { @jobs_count.zero?  }
        end
      end
    end
  end
end
