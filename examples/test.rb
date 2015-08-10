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

class TestController < Karafka::BaseController
  self.group = :karafka_api14
  self.topic = 'karafka_topic14'

  before_schedule {
    r = rand(50)
    params.merge!(first_round: r)
    r > 25
  }

  before_schedule {
    r = rand(50)
    params.merge!(next_round: r)
    r > 25
  }
  def perform
    puts "TestController params = #{params}"
  end
end

class AnotherTestController < Karafka::BaseController
  self.group = :karafka_api13
  self.topic = :karafka_topic13

  def perform
    puts "AnotherTestController params = #{params}"
  end
end

class Test
  def apply
    Karafka::Consumer.new.receive
  end
end


Test.new.apply
# rubocop:enable all