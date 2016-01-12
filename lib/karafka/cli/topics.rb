module Karafka
  # Karafka framework Cli
  class Cli
    desc 'topics', 'List all topics available on Karafka server (short-cut alias: "t")'
    # List all topics available on Karafka server
    def topics
      topics = []

      Karafka::App.config.zookeeper_hosts.each do |host|
        zookeeper = Zookeeper.new(host)
        topics += zookeeper.get_children(path: '/brokers/topics')[:children]
      end

      topics.sort.each { |topic| puts topic }
    end
  end
end
