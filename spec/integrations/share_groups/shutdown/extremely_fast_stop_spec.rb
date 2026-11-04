# frozen_string_literal: true

# Share group (KIP-932): when we stop right after run, it should not hang even on extreme edge
# cases.

setup_karafka

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Class.new(Karafka::ShareConsumer)
    end
  end
end

setup_share_group

Thread.new { Karafka::Server.stop }
Karafka::Server.run
