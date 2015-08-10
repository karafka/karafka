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
  config.kafka_hosts = ['127.0.0.1:9093']
  config.zookeeper_hosts = ['127.0.0.1:2181']
end


class Test2Controller < Karafka::BaseController
  self.group = :karafka_api14
  self.topic = 'karafka_topic14'


  def perform
    puts "Params of test2 Controller #{params}"
  end
end

class Test2aController < Karafka::BaseController
  self.group = :karafka_api13
  self.topic = 'karafka_topic13'



  def perform
    puts "Params of test2a Controller #{params}"
  end
end

class Test
  def apply
    Karafka::Consumer.new.receive
  end
end

Test.new.apply
# rubocop:enable all