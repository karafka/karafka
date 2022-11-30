# frozen_string_literal: true

# Karafka should work with Rails 6 and rspec/rails when it is required and should not crash
#
# @see https://github.com/karafka/karafka/issues/803

# Load all the Railtie stuff like when `rails server`
ENV['KARAFKA_CLI'] = 'true'

Bundler.require(:default)

ENV['RAILS_ENV'] = 'test'

# This integration spec requires only to load stuff. If nothing crashed, it means all works as
# expected
require 'rails'
require 'active_model/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'rspec/rails'
