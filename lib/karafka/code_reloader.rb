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

    # @param user_code_loaders [Object] any code loaders that we use in this app. Whether it is
    #  the Rails loader, Zeitwerk or anything else that allows reloading triggering
    def initialize(*user_code_loaders)
      @user_code_loaders = user_code_loaders
    end

    # Binds to the instrumentation events and triggers the user code loaders as well as Karafka app
    # after each fetched batch
    # @note Since we de-register all the user defined objects and redraw routes, it means that
    #   we won't be able to do a multi-batch buffering in the development mode as each of the
    #   batches will be buffered on a newly created "per fetch" instance.
    def on_connection_listener_fetch_loop(_event)
      MUTEX.synchronize do
        # Rails reloaders
        @user_code_loaders
          .select { |loader| loader.respond_to?(:reload!) }
          .each(&:reload!)

        # Zeitwerk and other reloaders
        @user_code_loaders
          .select { |loader| loader.respond_to?(:reload) }
          .each(&:reload)

        Karafka::App.reload
      end
    end
  end
end
