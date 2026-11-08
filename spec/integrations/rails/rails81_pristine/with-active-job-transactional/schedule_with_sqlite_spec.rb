# frozen_string_literal: true

# Karafka should work with Rails and AJ + #enqueue_after_transaction_commit

ENV["RAILS_ENV"] = "production"

# Load all the Railtie stuff like when `rails server`
ENV["KARAFKA_CLI"] = "true"

Bundler.require(:default)

require "fileutils"
require "action_controller"
require "active_support/railtie"
require "active_record"
require "active_job/karafka"
require "active_job/railtie"

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: "db/production.sqlite3"
)

class ExampleApp < Rails::Application
  config.eager_load = "production"
  config.active_job.enqueue_after_transaction_commit = :default
  config.active_job.queue_adapter = :karafka
end

dummy_boot_file = "#{Tempfile.new.path}.rb"
FileUtils.touch(dummy_boot_file)
ENV["KARAFKA_BOOT_FILE"] = dummy_boot_file

ExampleApp.initialize!

setup_karafka

draw_routes do
  active_job_topic DT.topic
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[0] << true
  end
end

ActiveRecord::Base.transaction do
  Job.perform_later
end
