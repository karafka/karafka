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
  self.group = :karafka_api2
  self.topic = 'karafka_topic4'

  before_action do
    puts 'BEFORE #14444'
    params.merge!({ :aaa43 => 4 })
    true
  end

  def process
    puts "PROCESS PROCESS PROCESS"
    # Karafka::Worker.perform_async(params)
  end
end

class Facebook2Controller < Karafka::BaseController
  self.group = :karafka_api2
  self.topic = 'karafka_topic3'

  before_action do
    puts 'BEFORE #1'
    params.merge!({ rand(99999) => 4 })
    true
  end

  before_action do
    puts 'BEFORE #2'
    params.merge!({ a: 3 })
    true
  end

  before_action do
    puts 'BEFORE #3'
    params.merge!({ b: 2 })
    true
  end

  before_action do
    puts 'BEFORE #4'
    params.merge!({ c: 1 })
    true
  end

  # before_action :a, :b
  #
  # def a
  #   puts 'BEFORE METHOD A'
  #   params.merge!({ met: 1 })
  #   true
  # end
  #
  # def b
  #   puts 'BEFORE METHOD B'
  #   params.merge!({ met2: 1 })
  #   true
  # end

  def process
    puts "Worker Worker Worker"
  end
end

class Test
  def apply
    Karafka::Consumer.new(
      ['127.0.0.1:9092', '127.0.0.1:9093'],
      ['127.0.0.1:2181', '127.0.0.1:2181']
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