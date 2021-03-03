# frozen_string_literal: true

ROOT_PATH = Pathname.new(File.expand_path(File.join(File.dirname(__FILE__), '../../')))
require ROOT_PATH.join('spec/integrations_helper.rb')

# Karafka CLI should work and should not fail

Karafka::Cli.prepare
Karafka::Cli.start
