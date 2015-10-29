%w(
  puma
  sidekiq/web
).each { |lib| require lib }

require "#{File.dirname(__FILE__)}/app.rb"

use Rack::Auth::Basic, 'Protected Area' do |username, password|
  username == 'sidekiq' &&
    password == 'Pa$$WorD!'
end

run Sidekiq::Web
