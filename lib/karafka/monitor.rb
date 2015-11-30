module Karafka
  # Monitor is used to hookup external monitoring services to monitor how Karafka works
  # It provides a standarized API for checking incoming messages/enqueueing etc
  # By default it implements logging functionalities but can be replaced with any more
  #   sophisticated logging/monitoring system like Errbit, Airbrake, NewRelic
  # @note This class acts as a singleton because we are only permitted to have single monitor
  #   per running process (just as logger)
  # Keep in mind, that if you create your own monitor object, you will have to implement also
  # logging functionality (or just inherit, super and do whatever you want)
  class Monitor
    include Singleton

    # This method is executed in many important places in the code (during data flow), like
    # the moment before #perform_async, etc. For full list just grep for 'monitor.notice'
    # @param [Class] class of object that executed this call
    # @param [Hash] hash with options that we passed to notice. It differs depent of who
    #   and when is calling
    # @note We don't provide a name of method in which this was called, because we can take
    #   it directly from Ruby (see #caller_label method of this class for more details)
    # @example Notice about consuming with controller_class
    #   Karafka.monitor.notice(self.class, controller_class: controller_class)
    def notice(caller_class, options = {})
      logger.info("#{caller_class}##{caller_label} with #{options}")
    end

    # This method is executed when we want to notify about an error that happened somewhere
    # in the system
    # @param [Class] class of object that executed this call
    # @param [Exception] exception that was raised
    # @note We don't provide a name of method in which this was called, because we can take
    #   it directly from Ruby (see #caller_label method of this class for more details)
    # @example Notify about error
    #   Karafka.monitor.notice(self.class, e)
    def notice_error(caller_class, e)
      return logger.error(e) if caller_class == Karafka::Connection::ActorCluster
      return logger.error(e) if caller_class == Karafka::Connection::Consumer
      return logger.error(e) if caller_class == Karafka::Connection::Listener
      return logger.fatal(e) if caller_class == Karafka::Runner

      logger.info(e)
    end

    private

    # @return [String] label of method that invoked #notice or #notice_error
    # @example Check label of method that invoked #notice
    #   caller_label #=> 'fetch'
    # @example Check label of method that invoked #notice in a block
    #   caller_label #=> 'block in fetch'
    # @example Check label of method that invoked #notice_error
    #   caller_label #=> 'rescue in target'
    def caller_label
      caller_locations(1, 2)[1].label
    end

    # @return [Logger] logger instance
    def logger
      Karafka.logger
    end
  end
end
