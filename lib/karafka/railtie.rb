# frozen_string_literal: true

# This file contains Railtie for auto-configuration
begin
  # Try to load Rails and if exists it will continue
  require 'rails'
  # Load Karafka
  require 'karafka'
  # Load ActiveJob adapter
  require 'active_job/queue_adapters/karafka_adapter'
  require 'active_job/consumer'
  require 'active_job/routing_extensions'

  # Setup env if configured (may be configured later by .net, etc)
  ENV['KARAFKA_ENV'] ||= ENV['RAILS_ENV'] if ENV.key?('RAILS_ENV')

  # We extend routing builder by adding a simple wrapper for easier jobs topics defining
  ::Karafka::Routing::Builder.include ActiveJob::RoutingExtensions

  module Karafka
    # Railtie for setting up Rails integration
    class Railtie < Rails::Railtie
      railtie_name :karafka

      initializer 'karafka.configure_rails_initialization' do |app|
        # Consumers should autoload by default in the Rails app so they are visible
        app.config.autoload_paths += %w[app/consumers]

        # Make Karafka use Rails logger
        ::Karafka::App.config.logger = Rails.logger

        # This lines will make Karafka print to stdout like puma or unicorn
        if Rails.env.development?
          Rails.logger.extend(
            ActiveSupport::Logger.broadcast(
              ActiveSupport::Logger.new($stdout)
            )
          )
        end

        app.reloader.to_prepare do
          # Load Karafka bot file, so it can be used in Rails server context
          require Rails.root.join(Karafka.boot_file.to_s).to_s
        end
      end
    end
  end
rescue LoadError
  # Without defining this in any way, Zeitwerk ain't happy so we do it that way
  module Karafka
    class Railtie
    end
  end
end
