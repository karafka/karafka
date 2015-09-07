require 'bundler'
require 'rake'
require 'polishgeeks-dev-tools'

PolishGeeks::DevTools.setup do |config|
  config.brakeman = false
  config.haml_lint = false
  config.empty_method_ignored = %w(
    spec/lib/karafka/base_controller_spec.rb
    spec/lib/karafka/connection/cluster_spec.rb
    spec/lib/karafka/connection/consumer_spec.rb
    spec/lib/karafka/connection/listener_spec.rb
    spec/lib/karafka/routing/router_spec.rb
    spec/lib/karafka/worker_spec.rb
  )
end

desc 'Self check using polishgeeks-dev-tools'
task :check do
  PolishGeeks::DevTools::Runner.new.execute(
    PolishGeeks::DevTools::Logger.new
  )
end

task default: :check
