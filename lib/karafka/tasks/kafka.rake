namespace :kafka do
  desc 'Lists all the topics available on a Kafka server'
  task :topics do
    Karafka::App.config.zookeeper_hosts.each do |host|
      zookeeper = Zookeeper.new(host)
      topics = zookeeper.get_children(path: '/brokers/topics')[:children]
      topics.each { |topic| puts topic }
    end
  end
end
