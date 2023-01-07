# frozen_string_literal: true

module Karafka
  # Class used to catch signals from ruby Signal class in order to manage Karafka stop
  # @note There might be only one process - this class is a singleton
  class Process
    # Signal types that we handle
    HANDLED_SIGNALS = %i[
      SIGINT
      SIGQUIT
      SIGTERM
      SIGTTIN
      SIGTSTP
    ].freeze

    HANDLED_SIGNALS.each do |signal|
      # Assigns a callback that will happen when certain signal will be send
      # to Karafka server instance
      # @note It does not define the callback itself -it needs to be passed in a block
      # @example Define an action that should be taken on_sigint
      #   process.on_sigint do
      #     Karafka.logger.info('Log something here')
      #     exit
      #   end
      define_method :"on_#{signal.to_s.downcase}" do |&block|
        @callbacks[signal] << block
      end
    end

    # Creates an instance of process and creates empty hash for callbacks
    def initialize
      @callbacks = Hash.new { |hsh, key| hsh[key] = [] }
      @supervised = false
    end

    # Method catches all HANDLED_SIGNALS and performs appropriate callbacks (if defined)
    # @note If there are no callbacks, this method will just ignore a given signal that was sent
    def supervise
      HANDLED_SIGNALS.each { |signal| trap_signal(signal) }
      @supervised = true
    end

    # Is the current process supervised and are trap signals installed
    def supervised?
      @supervised
    end

    private

    # Traps a single signal and performs callbacks (if any) or just ignores this signal
    # @param [Symbol] signal type that we want to catch
    # @note Since we do a lot of threading and queuing, we don't want to handle signals from the
    # trap context s some things may not work there as expected, that is why we spawn a separate
    # thread to handle the signals process
    def trap_signal(signal)
      previous_handler = ::Signal.trap(signal) do
        Thread.new do
          notice_signal(signal)

          (@callbacks[signal] || []).each(&:call)
        end

        previous_handler.call if previous_handler.respond_to?(:call)
      end
    end

    # Informs monitoring about trapped signal
    # @param [Symbol] signal type that we received
    def notice_signal(signal)
      Karafka.monitor.instrument('process.notice_signal', caller: self, signal: signal)
    end
  end
end
