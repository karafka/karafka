require 'bundler'

Bundler.require(:default, :test, :integrations)

require 'rails' if Bundler.locked_gems.specs.any? { |spec| spec.name == 'railties' }
require 'active_job/railtie' if Bundler.locked_gems.specs.any? { |spec| spec.name == 'activejob' }

require_relative './integrations_helper'

require ARGV.fetch(0)
