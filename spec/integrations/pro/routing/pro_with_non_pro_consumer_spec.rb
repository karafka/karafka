# frozen_string_literal: true

# All consumers when Pro should inherit from Karafka::Pro::BaseConsumer

setup_karafka do |config|
  config.license.token = pro_license_token
end

guarded = []

begin
  draw_routes do
    consumer_group 'regular' do
      topic 'regular' do
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << 1
end

Karafka::App.routes.clear

begin
  draw_routes do
    consumer_group 'regular2' do
      topic 'regular2' do
        consumer Class.new(Karafka::Pro::BaseConsumer)
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << 2
end

assert_equal [1], guarded
