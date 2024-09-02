# frozen_string_literal: true

# This file contains Railtie for auto-configuration

unless Karafka.rails?
  # Without defining this in any way, Zeitwerk ain't happy so we do it that way
  module Karafka
    class Railtie
    end
  end
end

if Karafka.rails?
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
        # Make Karafka uses Rails logger
        ::Karafka::App.config.logger = Rails.logger

        next unless Rails.env.development?
        next unless ENV.key?('KARAFKA_CLI')
        # If we are already publishing to STDOUT, no need to add it again.
        # If added again, would print stuff twice
        next if ActiveSupport::Logger.logger_outputs_to?(Rails.logger, $stdout)

        stdout_logger = ActiveSupport::Logger.new($stdout)
        # Inherit the logger level from Rails, otherwise would always run with the debug level
        stdout_logger.level = Rails.logger.level

        rails71plus = Rails.gem_version >= Gem::Version.new('7.1.0')

        # Rails 7.1 replaced the broadcast module with a broadcast logger
        if rails71plus
          Rails.logger.broadcast_to(stdout_logger)
        else
          Rails.logger.extend(
            ActiveSupport::Logger.broadcast(
              stdout_logger
            )
          )
        end
      end

      initializer 'karafka.configure_rails_auto_load_paths' do |app|
        # Consumers should autoload by default in the Rails app so they are visible
        app.config.autoload_paths += %w[app/consumers]
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

      initializer 'karafka.configure_worker_external_executor' do |app|
        app.config.after_initialize do
          app_config = Karafka::App.config

          # We need to wrap execution of the core user code with a wrapper in case of Rails, so
          # the auto-reload works as expected
          worker_job_call_wrapper = app_config.consumer_persistence ? app.executor : app.reloader
          app_config.internal.processing.worker_job_call_wrapper = worker_job_call_wrapper
        end
      end
    end
  end
end
