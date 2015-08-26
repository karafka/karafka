module Karafka
  # App status monitor
  class Status
    include Singleton

    # Mark application as running
    def run!
      @status = :running
    end

    # Mark application as stopped
    def stop!
      @status = :stopped
    end

    # Check if application should run
    def running?
      @status == :running
    end
  end
end
