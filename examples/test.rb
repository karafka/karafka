# rubocop:disable all
# require 'karafka/consumer'
require 'poseidon'
require 'poseidon_cluster'
require 'resolv-replace.rb'
require 'karafka'
require 'sidekiq'
folders_path = File.dirname(__FILE__) + '/karafka/*.rb'
Dir[folders_path].each { |file| require file }


class Facebook22Controller < Karafka::BaseController
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
    puts "PROCESS PROCESS PROCESS #{params}"
    # Karafka::Worker.perform_async(params)
  end
end

class Facebook2Controller < Karafka::BaseController
  self.group = :karafka_api13
  self.topic = :karafka_topic13

  def perform
    puts "Worker Worker Worker  #{params}"
  end
end

class Test
  def apply
    Karafka::Consumer.new(
      ['127.0.0.1:9093'],
      ['127.0.0.1:2181']
    ).receive

    # Karafka::App.new(, 'karafka_topic3').call
  end
end

::Karafka::Config.configure do |config|
  # config.socket_timeout_ms = 50_000
  # config.application = 'application_name'
  # config.kafka = ['127.0.0.1:9092', '127.0.0.1:9093']
  # config.zookeeper = ['127.0.0.1:2181', '127.0.0.1:2181']
  # config.redis_url = 'redis://127.0.0.1:6379/0'
end

Test.new.apply
# rubocop:enable all