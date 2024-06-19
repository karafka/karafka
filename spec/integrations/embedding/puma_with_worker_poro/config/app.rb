# frozen_string_literal: true

require 'sinatra'

# Just a fake endpoint to have an app
get '/' do
  content_type :json
  { 'ping' => 'pong' }.to_json
end
