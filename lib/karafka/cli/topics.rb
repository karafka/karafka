module Karafka
  # Karafka framework Cli
  class Cli
    # Topics Karafka Cli action
    class Topics < Base
      self.desc = 'List all topics available on Karafka server (short-cut alias: "t")'
      self.options = { aliases: 't' }

      # List all topics available on Karafka server
      def call
        topics = []

        Karafka::App.config.zookeeper_hosts.each do |host|
          zookeeper = Zookeeper.new(host)
          path = File.join(::Karafka::App.config.zookeeper_base_znode || '', 'brokers', 'topics')
          topics += zookeeper.get_children(path: path)[:children]
        end

        topics.sort.each { |topic| puts topic }
      end
    end
  end
end
