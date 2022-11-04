require 'rails' if ENV.key?('RAILS')
require_relative './integrations_helper'

require ARGV.fetch(0)
