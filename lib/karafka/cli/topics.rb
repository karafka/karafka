module Karafka
  # Karafka framework Cli
  class Cli
    desc 'topics', 'Lists all topics available on Karafka server (short-cut alias: "t")'
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
