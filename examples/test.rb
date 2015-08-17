# rubocop:disable all
# require 'karafka/consumer'
require 'poseidon'
require 'poseidon_cluster'
require 'resolv-replace.rb'
require 'karafka'
require 'sidekiq'
require 'sidekiq_glass'
require './run_test'
require 'karafka/base_worker'

::Karafka.setup do |config|
  config.kafka_hosts = ['127.0.0.1:9093']
  config.zookeeper_hosts = ['127.0.0.1:2181']
end

Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://127.0.0.1:6379/0' }
end

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://127.0.0.1:6379/0' }
end

class Test
  def apply
    Karafka::Consumer.new.receive
  end
end

Test.new.apply
# rubocop:enable all
