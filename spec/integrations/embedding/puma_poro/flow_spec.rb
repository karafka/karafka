# frozen_string_literal: true

# Karafka should run from a Puma server easily

Bundler.require(:default)

system('bundle exec ruby app/sinatra.rb -s puma')

# No need to do anything here. If Karafka embedded in puma does not start, it will basically
# make Puma hang forever and will be killed with notice by the supervisor.
