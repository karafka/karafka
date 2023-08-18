# frozen_string_literal: true

# When we stop right after run, it should not hang even on extreme edge cases

setup_karafka

draw_routes(Class.new)

Thread.new { Karafka::Server.stop }
Karafka::Server.run
