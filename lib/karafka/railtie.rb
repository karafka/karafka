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

      # This lines will make Karafka print to stdout like puma or unicorn when we run karafka
      # server + will support code reloading with each fetched loop. We do it only for karafka
      # based commands as Rails processes and console will have it enabled already
      initializer 'karafka.configure_rails_logger' do
        # Make Karafka use Rails logger
        ::Karafka::App.config.logger = Rails.logger

        next unless Rails.env.development?
        next unless ENV.key?('KARAFKA_CLI')

        Rails.logger.extend(
          ActiveSupport::Logger.broadcast(
            ActiveSupport::Logger.new($stdout)
          )
        )
      end

      initializer 'karafka.configure_rails_auto_load_paths' do |app|
        # Consumers should autoload by default in the Rails app so they are visible
        app.config.autoload_paths += %w[app/consumers]
      end

      initializer 'karafka.configure_rails_code_reloader' do
        # There are components that won't work with older Rails version, so we check it and
        # provide a failover
        rails6plus = Rails.gem_version >= Gem::Version.new('6.0.0')

        next unless Rails.env.development?
        next unless ENV.key?('KARAFKA_CLI')
        next unless rails6plus

        # We can have many listeners, but it does not matter in which we will reload the code
        # as long as all the consumers will be re-created as Rails reload is thread-safe
        ::Karafka::App.monitor.subscribe('connection.listener.fetch_loop') do
          # Reload code each time there is a change in the code
          next unless Rails.application.reloaders.any?(&:updated?)

          Rails.application.reloader.reload!
        end
      end

      initializer 'karafka.require_karafka_boot_file' do |app|
        rails6plus = Rails.gem_version >= Gem::Version.new('6.0.0')

        # If the boot file location is set to "false", we should not raise an exception and we
        # should just not load karafka stuff. Setting this explicitly to false indicates, that
        # karafka is part of the supply chain but it is not a first class citizen of a given
        # system (may be just a dependency of a dependency), thus railtie should not kick in to
        # load the non-existing boot file
        next if Karafka.boot_file.to_s == 'false'

        karafka_boot_file = Rails.root.join(Karafka.boot_file.to_s).to_s

        # Provide more comprehensive error for when no boot file
        unless File.exist?(karafka_boot_file)
          raise(Karafka::Errors::MissingBootFileError, karafka_boot_file)
        end

        if rails6plus
          app.reloader.to_prepare do
            # Load Karafka boot file, so it can be used in Rails server context
            require karafka_boot_file
          end
        else
          # Load Karafka main setup for older Rails versions
          app.config.after_initialize do
            require karafka_boot_file
          end
        end
      end
    end
  end
end
