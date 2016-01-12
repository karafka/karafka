%w(
  puma
  sidekiq/web
).each { |lib| require lib }

require Karafka.boot_file

use Rack::Auth::Basic, 'Protected Area' do |username, password|
  username == 'sidekiq' &&
    password == 'Pa$$WorD!'
end

run Sidekiq::Web
