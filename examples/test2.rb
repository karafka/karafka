# rubocop:disable all
# require 'karafka/consumer'
require 'poseidon'
require 'poseidon_cluster'
require 'resolv-replace.rb'
require 'karafka'
require 'sidekiq'
folders_path = File.dirname(__FILE__) + '/karafka/*.rb'
Dir[folders_path].each { |file| require file }

::Karafka::Config.configure do |config|
  # config.socket_timeout_ms = 50_000
  # config.application = 'application_name'
  config.kafka_hosts = ['127.0.0.1:9093']
  config.zookeeper_hosts = ['127.0.0.1:2181']
  # config.redis_url = 'redis://127.0.0.1:6379/0'
end


class GGGGGGController < Karafka::BaseController
  self.group = :karafka_api14
  self.topic = 'karafka_topic14'


  def perform
    puts "WthS #{params}"
    # Karafka::Worker.perform_async(params)
  end
end

class Rrrrrrrr2Controller < Karafka::BaseController
  self.group = :karafka_api13
  self.topic = 'karafka_topic13'



  def perform
    puts "Wth FFFFFFFFFFFFFFFFFFF #{params}"
  end
end

class Test
  def apply
    Karafka::Consumer.new.receive
  end
end

Test.new.apply
# rubocop:enable all