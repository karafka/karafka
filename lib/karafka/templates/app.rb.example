ENV['RACK_ENV'] ||= 'development'
ENV['KARAFKA_ENV'] ||= ENV['RACK_ENV']

Bundler.require(:default, ENV['KARAFKA_ENV'])

Karafka::Loader.new.load(File.dirname(__FILE__))

# App class
class App < Karafka::App
  setup do |config|
    config.kafka_hosts = %w( 127.0.0.1:9092 )
    config.zookeeper_hosts = %w( 127.0.0.1:2181 )
    config.worker_timeout = 60 # 1 minute
    config.concurrency = 5
    config.name = 'example_app'
    config.redis = {
      url: 'redis://localhost:6379'
    }
  end
end
