# frozen_string_literal: true

# The content of this file is tricky.
# Karafka itself works in two modes:
# - cli commands and karafka.rb based stuff (server, worker, etc)
# - karafka.rb loaded into rails
#
# Karafka can also be used in two ways:
# - part of a bigger framework like Rails
# - standalone mode where it is a bare app
#
# Due to that, we have to support all the cases below
# @note For other framework nothing bad should happen, as it can still be
# easily integrated manually

# If Rails is preloaded, it means that Karafka is required from within a already
# running Rails process, which means, that we need to load Karafka stuff but not
# loade gemes, etc as it is already handled
rails_preloaded = defined?(Rails)
rails_app = false

# Detection if we have Rails as one of gems
begin
  require 'rails'
  rails_app = true
rescue LoadError
  rails_app = false
end

# If this is a Rails env or a Rails based app, lets set stuff based on it's env
if rails_preloaded || rails_app
  ENV['RAILS_ENV'] ||= 'development'
  ENV['KARAFKA_ENV'] ||= ENV['RAILS_ENV']
else
  ENV['RACK_ENV'] ||= 'development'
  ENV['KARAFKA_ENV'] ||= ENV['RACK_ENV']
end

Karafka::Loader.load!(Karafka.core_root)

if rails_preloaded
  # Railtie used to load Karafka stuff into Rails, so all routes, etc are available
  # from Rails console and in other Rails related places
  # @note This will load Karafka to Rails, not the other way around
  Class.new(Rails::Railtie) do
    config.to_prepare do
      p 'aaaaaaaaaa'
      require Karafka.boot_file
    end
  end
elsif rails_app
  # Loading Rails to Karafka if needed
  require File.join(Karafka.root, './config/environment')
  Rails.application.eager_load!
else
  Bundler.require(:default, ENV['KARAFKA_ENV'])
  Karafka::Loader.load(Karafka::App.root)
end
