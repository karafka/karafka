# frozen_string_literal: true

# When `bootstrap.servers` comes from an unset or empty ENV variable (`nil` or `""`), drawing
# consumer group and share group routes must fail with an error that names the setting, instead
# of booting a server that never connects

setup_karafka

valid_kafka = Karafka::App.config.kafka

draws = {
  consumer_group: lambda do
    draw_routes(create_topics: false) do
      consumer_group DT.group do
        topic DT.topic do
          active(false)
        end
      end
    end
  end,
  share_group: lambda do
    draw_routes(create_topics: false) do
      share_group DT.group do
        topic DT.topic do
          active(false)
        end
      end
    end
  end
}

[nil, ""].each do |servers|
  Karafka::App.config.kafka = valid_kafka.merge("bootstrap.servers": servers)

  draws.each do |group_type, draw|
    clear_app_draws

    error = nil

    begin
      draw.call
    rescue Karafka::Errors::InvalidConfigurationError => e
      error = e
    end

    assert error&.message&.include?("bootstrap.servers"), [group_type, servers, error]
  end
end

Karafka::App.config.kafka = valid_kafka
clear_app_draws

draws.fetch(:consumer_group).call
