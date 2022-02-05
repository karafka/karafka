# frozen_string_literal: true

# This file contains Railtie for auto-configuration

rails = false

begin
  require 'rails'

  rails = true
rescue LoadError
  # Without defining this in any way, Zeitwerk ain't happy so we do it that way
  module Karafka
    class Railtie
    end
  end
end

if rails
  # Load Karafka
  require 'karafka'

  # Load ActiveJob adapter
  require 'active_job/karafka'

  # Setup env if configured (may be configured later by .net, etc)
  ENV['KARAFKA_ENV'] ||= ENV['RAILS_ENV'] if ENV.key?('RAILS_ENV')

  module Karafka
    # Railtie for setting up Rails integration
    class Railtie < Rails::Railtie
      railtie_name :karafka

      initializer 'karafka.active_job_integration' do
        ActiveSupport.on_load(:active_job) do
          # Extend ActiveJob with some Karafka specific ActiveJob magic
          extend ::Karafka::ActiveJob::JobExtensions
        end
      end

      initializer 'karafka.configure_rails_initialization' do |app|
        # Consumers should autoload by default in the Rails app so they are visible
        app.config.autoload_paths += %w[app/consumers]

        # Make Karafka use Rails logger
        ::Karafka::App.config.logger = Rails.logger

        # This lines will make Karafka print to stdout like puma or unicorn when we run karafka
        # server + will support code reloading with each fetched loop. We do it only for karafka
        # based commands as Rails processes and console will have it enabled already
        if Rails.env.development? && ENV.key?('KARAFKA_CLI')
          Rails.logger.extend(
            ActiveSupport::Logger.broadcast(
              ActiveSupport::Logger.new($stdout)
            )
          )

          # We can have many listeners, but it does not matter in which we will reload the code as
          # long as all the consumers will be re-created as Rails reload is thread-safe
          ::Karafka::App.monitor.subscribe('connection.listener.fetch_loop') do
            # Reload code each time there is a change in the code
            next unless Rails.application.reloaders.any?(&:updated?)

            Rails.application.reloader.reload!
          end
        end

        app.reloader.to_prepare do
          # Load Karafka bot file, so it can be used in Rails server context
          require Rails.root.join(Karafka.boot_file.to_s).to_s
        end
      end
    end
  end
end
