# frozen_string_literal: true

require "sinatra"

# Minimal rack app — just a ping endpoint to keep Puma alive until we trigger shutdown
get "/" do
  content_type :json
  { "ping" => "pong" }.to_json
end
