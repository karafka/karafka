require 'bundler'

require 'rails' if Bundler.require(:default, :test, :integrations).any? { |gem| gem.name == 'railties' }

require_relative './integrations_helper'

require ARGV.fetch(0)
