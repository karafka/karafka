# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka+Pro should work with Rails 7 using the default setup

# Load all the Railtie stuff like when `rails server`
ENV['KARAFKA_CLI'] = 'true'

Bundler.require(:default)

require 'tempfile'

dummy_boot_file = "#{Tempfile.new.path}.rb"
FileUtils.touch(dummy_boot_file)
ENV['KARAFKA_BOOT_FILE'] = dummy_boot_file

mod = Module.new do
  def self.token
    ENV.fetch('KARAFKA_PRO_LICENSE_TOKEN')
  end
end

Karafka.const_set('License', mod)
require 'karafka/pro/loader'

Karafka::Pro::Loader.require_all

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end
end

failed = false

begin
  draw_routes do
    recurring_tasks(true)
  end
rescue Karafka::Errors::DependencyConstraintsError
  failed = true
end

assert failed
