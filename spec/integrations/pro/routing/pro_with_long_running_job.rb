# frozen_string_literal: true

# I should be able to define a topic consumption with long-running job indication
# It should not impact other jobs and the default should not be lrj

setup_karafka do |config|
  config.license.token = pro_license_token
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topics[0] do
      consumer Class.new(Karafka::Pro::BaseConsumer)
      long_running_job true
    end

    topic DataCollector.topics[1] do
      consumer Class.new(Karafka::Pro::BaseConsumer)
      long_running_job false
    end

    topic DataCollector.topics[2] do
      consumer Class.new(Karafka::Pro::BaseConsumer)
      long_running_job false
    end
  end
end

assert Karafka::App.routes.first.topics[0].long_running_job?
assert_equal false, Karafka::App.routes.first.topics[1].long_running_job?
assert_equal false, Karafka::App.routes.first.topics[2].long_running_job?
