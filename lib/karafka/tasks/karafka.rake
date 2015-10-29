namespace :karafka do
  desc 'Runs a single Karafka processing instance'
  task :run do
    puts('Starting Karafka framework')
    puts("Environment: #{Karafka.env}")
    puts("Kafka hosts: #{Karafka::App.config.kafka_hosts}")
    puts("Zookeeper hosts: #{Karafka::App.config.zookeeper_hosts}")
    Karafka::App.run
  end

  desc 'Runs a single Sidekiq worker for Karafka'
  task :sidekiq do
    require_file = Karafka::App.root.join('app.rb')
    config_file = Karafka::App.root.join('config/sidekiq.yml')

    puts('Starting Karafka Sidekiq')
    puts("Environment: #{Karafka.env}")
    puts("Kafka hosts: #{Karafka::App.config.kafka_hosts}")
    puts("Zookeeper hosts: #{Karafka::App.config.zookeeper_hosts}")
    cmd = "bundle exec sidekiq -e #{Karafka.env} -r #{require_file} -C #{config_file}"
    puts(cmd)
    system (cmd)
  end

  desc 'Creates whole minimal app structure'
  task :install do
    require 'fileutils'

    %w(
      app/models
      app/controllers
      config
      log
    ).each do |dir|
      FileUtils.mkdir_p dir
    end

    {
      'app.rb.example' => 'app.rb',
      'config.ru.example' => 'config.ru',
      'rakefile.rb.example' => 'rakefile.rb',
      'sidekiq.yml.example' => 'config/sidekiq.yml.example'
    }.each do |source, target|
      FileUtils.cp_r(
        Karafka.core_root.join("templates/#{source}"),
        Karafka::App.root.join(target)
      )
    end
  end
end
