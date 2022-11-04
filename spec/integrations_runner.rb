require 'bundler'
Bundler.setup(:default, :test, :integrations)

require 'karafka'
require_relative './integrations_helper'

require ARGV.fetch(0)
