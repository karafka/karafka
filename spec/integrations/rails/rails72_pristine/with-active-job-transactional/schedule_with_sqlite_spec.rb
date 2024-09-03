# frozen_string_literal: true

# Karafka should work with Rails and AJ + #enqueue_after_transaction_commit

ENV['RAILS_ENV'] = 'production'

# Load all the Railtie stuff like when `rails server`
ENV['KARAFKA_CLI'] = 'true'

Bundler.require(:default)

require 'tempfile'
require 'fileutils'
require 'action_controller'
require 'active_support/railtie'
require 'active_record'
require 'active_job/karafka'
require 'active_job/railtie'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'db/production.sqlite3'
)

database_yml_content = <<-YAML
  default: &default
    adapter: sqlite3
    pool: 5
    timeout: 5000

  production:
    <<: *default
    database: db/production.sqlite3
YAML

# Define the path where the database.yml should be saved
config_dir = 'config'
database_yml_path = File.join(config_dir, 'database.yml')

# Ensure the config directory exists
FileUtils.mkdir_p(config_dir)

# Write the string to the database.yml file
File.open(database_yml_path, 'w') do |file|
  file.write(database_yml_content)
end

class ExampleApp < Rails::Application
  config.eager_load = 'production'
  config.active_job.enqueue_after_transaction_commit = :default
  config.active_job.queue_adapter = :karafka
end

ActiveJob::Base.extend ::Karafka::ActiveJob::JobExtensions

dummy_boot_file = "#{Tempfile.new.path}.rb"
FileUtils.touch(dummy_boot_file)
ENV['KARAFKA_BOOT_FILE'] = dummy_boot_file

ExampleApp.initialize!

setup_karafka do |config|
  config.concurrency = 1
end

draw_routes do
  active_job_topic DT.topic
end

class Job < ActiveJob::Base
  queue_as DT.topic

  self.enqueue_after_transaction_commit = :default

  def perform
    DT[0] << true
  end
end

class User < ActiveRecord::Base
end

class CreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      t.string :name
    end
  end
end

ActiveRecord::Schema.define do
  CreateUsers.new.change
end

ActiveJob::Base.enqueue_after_transaction_commit = :default

User.transaction do
  User.create!(name: 'test')

  Job.perform_later
end
