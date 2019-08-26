# frozen_string_literal: true

module Karafka
  # Special type of a listener, that is not an instrumentation one, but one that triggers
  # code reload in the development mode after each fetched batch (or message)
  #
  # Please refer to the development code reload sections for details on the benefits and downsides
  # of the in-process code reloading
  class CodeReloader
    # This mutex is needed as we might have an application that has multiple consumer groups
    # running in separate threads and we should not trigger reload before fully reloading the app
    # in previous thread
    MUTEX = Mutex.new

    private_constant :MUTEX

    # @param reloaders [Array<Object>] any code loaders that we use in this app. Whether it is
    #  the Rails loader, Zeitwerk or anything else that allows reloading triggering
    # @param block [Proc] yields given block just before reloading. This can be used to hook custom
    #   reloading stuff, that ain't reloaders (for example for resetting dry-events registry)
    def initialize(*reloaders, &block)
      @reloaders = reloaders
      @block = block
    end

    # Binds to the instrumentation events and triggers reload
    # @param _event [Dry::Event] empty dry event
    # @note Since we de-register all the user defined objects and redraw routes, it means that
    #   we won't be able to do a multi-batch buffering in the development mode as each of the
    #   batches will be buffered on a newly created "per fetch" instance.
    def on_connection_listener_fetch_loop(_event)
      reload
    end

    private

    # Triggers reload of both standard and Rails reloaders as well as expires all internals of
    # Karafka, so it can be rediscovered and rebuilt
    def reload
      MUTEX.synchronize do
        if @reloaders[0].respond_to?(:execute)
          reload_with_rails
        else
          reload_without_rails
        end
      end
    end

    # Rails reloading procedure
    def reload_with_rails
      updatable = @reloaders.select(&:updated?)

      return if updatable.empty?

      updatable.each(&:execute)
      @block&.call
      Karafka::App.reload
    end

    # Zeitwerk and other reloaders
    def reload_without_rails
      @reloaders.each(&:reload)
      @block&.call
      Karafka::App.reload
    end
  end
end
