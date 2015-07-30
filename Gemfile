source 'https://rubygems.org'
gem 'poseidon'

# Specify your gem's dependencies in strike-event-delegator.gemspec
gemspec

# Will add appropriate strike gem to the Gemfile
# @param [String] strike gem name (without strike- prefix)
def strike_gem(gem_name)
  path = "ssh://git@git.dev.striketech.pl:2222/internal/strike-#{gem_name}.git"
  gem "strike-#{gem_name}", git: path
end

group :development, :test do
  strike_gem 'dev-tools'
  strike_gem 'docs'
end
