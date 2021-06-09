# frozen_string_literal: true

# This file contains Railtie for auto-configuration
begin
  require 'karafka'
  require 'rails'

  module Karafka
    # Railtie for setting up Rails integration
    class Railtie < Rails::Railtie
      railtie_name :karafka

      initializer 'karafka.configure_rails_initialization' do |app|
        app.config.autoload_paths += %w[app/consumers]

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
          require Rails.root.join(Karafka.boot_file)
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
