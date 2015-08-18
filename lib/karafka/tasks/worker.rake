require 'rake'
require 'karafka'

namespace :karafka do
  desc 'Runs sidekiq worker with sidekiq.yml config'
  task :run_worker, [:yml_link] do |_t, args|
    system ("bundle exec sidekiq -r #{Karafka.core_root}/base_worker.rb -C #{args[:yml_link]}")
  end
end
