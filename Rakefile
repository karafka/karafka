require 'bundler'
require 'bundler/gem_tasks'
require 'rake'
require 'polishgeeks-dev-tools'

PolishGeeks::DevTools.setup do |config|
  config.brakeman = false
  config.haml_lint = false
  config.simplecov_threshold = 100
end

desc 'Self check using polishgeeks-dev-tools'
task :check do
  PolishGeeks::DevTools::Runner.new.execute(
    PolishGeeks::DevTools::Logger.new
  )
end

task default: :check
