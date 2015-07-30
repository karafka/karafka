require 'bundler'
require 'bundler/gem_tasks'
require 'rake'
require 'strike-dev-tools'
require 'strike-docs'

Strike::Docs::Config.configure do
end

Strike::DevTools::Config.configure do |config|
  config.brakeman = false
  config.haml_lint = false
  config.simplecov_threshold = 97
end

desc 'Self check using strike-dev-tools'
task :check do
  Strike::DevTools::Runner.new.execute(
    Strike::DevTools::Logger.new
  )
end

task default: :check
