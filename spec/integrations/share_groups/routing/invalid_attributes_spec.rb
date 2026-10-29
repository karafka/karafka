# frozen_string_literal: true

# Share group (KIP-932) routing should be validated the same way as consumer group routing:
# invalid group and topic names, share groups without topics, non-positive max_messages and too
# small max_wait_time must be rejected with an InvalidConfigurationError.

setup_karafka

Consumer = Class.new(Karafka::ShareConsumer)

cases = {
  "routes.%^&*(.id" => proc do
    share_group "%^&*(" do
      topic "t" do
        consumer Consumer
      end
    end
  end,
  "routes.sg.%^&*(.name" => proc do
    share_group "sg" do
      topic "%^&*(" do
        consumer Consumer
      end
    end
  end,
  "routes.sg.topics" => proc do
    share_group "sg" do
      # no topics
    end
  end,
  "routes.sg.t.max_messages" => proc do
    share_group "sg" do
      topic "t" do
        consumer Consumer
        max_messages 0
      end
    end
  end,
  "routes.sg.t.max_wait_time" => proc do
    share_group "sg" do
      topic "t" do
        consumer Consumer
        max_wait_time 1
      end
    end
  end
}

cases.each do |key, routes|
  failed = false

  begin
    draw_routes(create_topics: false, &routes)
  rescue Karafka::Errors::InvalidConfigurationError => e
    assert e.message.include?(key), e.message

    failed = true
  end

  assert failed, key

  clear_app_draws
end
