# frozen_string_literal: true

# When reconfiguring kafka scope without providing bootstrap.servers, we should fail

setup_karafka

failed = false

begin
  draw_routes(create_topics: false) do
    topic 'name1' do
      active(false)
      # Reconfiguration without inherit like this should fail
      kafka('enable.partition.eof': true)
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed

Karafka::App.routes.clear

draw_routes(create_topics: false) do
  topic 'name2' do
    active(false)
    # Reconfiguration with inherit like this should not fail
    kafka('enable.partition.eof': true, inherit: true)
  end
end
