module Karafka
  # Default logger for Event Delegator
  # @note It uses ::Logger features - providing basic logging
  class Logger < ::Logger
    # Map containing informations about log level for given environment
    ENV_MAP = {
      'production' => ::Logger::ERROR,
      'test' => ::Logger::INFO,
      'development' => ::Logger::DEBUG,
      default: ::Logger::INFO
    }

    # Builds a logger with appropriate settings, log level and environment
    def self.build
      instance = new(Karafka::App.root.join('log', "#{Karafka.env}.log"))
      instance.level = ENV_MAP[Karafka.env] || ENV_MAP[:default]
      instance
    end
  end
end
