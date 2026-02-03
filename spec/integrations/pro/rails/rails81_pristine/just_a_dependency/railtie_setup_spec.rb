# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Karafka+Pro should work with Rails 8.1 using the default setup

# Load all the Railtie stuff like when `rails server`
ENV["KARAFKA_CLI"] = "true"

Bundler.require(:default)

require "tempfile"
require "action_controller"

class ExampleApp < Rails::Application
  config.eager_load = "test"
end

dummy_boot_file = "#{Tempfile.new.path}.rb"
FileUtils.touch(dummy_boot_file)
ENV["KARAFKA_BOOT_FILE"] = dummy_boot_file

ExampleApp.initialize!

mod = Module.new do
  def self.token
    ENV.fetch("KARAFKA_PRO_LICENSE_TOKEN")
  end

  def self.version
    "1.0.0"
  end
end

Karafka.const_set(:License, mod)
require "karafka/pro/loader"

Karafka::Pro::Loader.require_all

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end
end

draw_routes(Consumer)
produce(DT.topic, "1")

start_karafka_and_wait_until do
  DT.key?(0)
end

assert_equal 1, DT.data.size
assert Rails.version.starts_with?("8.1.")
assert Karafka.pro?
