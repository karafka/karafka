# frozen_string_literal: true

# Karafka should fail when defined routing is invalid
# Karafka should fail if we want to listen on a topic that was not defined

setup_karafka

guarded = []

begin
  draw_routes(create_topics: false) do
    consumer_group 'regular' do
      topic '#$%^&*(' do
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?('routes.')
  assert e.message.include?('regular')
  assert e.message.include?('#$%^&*(')
  guarded << true
end

Karafka::App.routes.clear

begin
  draw_routes(create_topics: false) do
    consumer_group '#$%^&*(' do
      topic 'regular' do
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?('routes.')
  assert e.message.include?('#$%^&*(')
  guarded << true
end

ARGV[0] = 'server'
ARGV[1] = '--consumer-groups'
ARGV[2] = 'non-existing'

begin
  Karafka::Cli.start
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?('Unknown consumer group name')
  assert e.message.include?('cli.include_consumer_groups')

  guarded << true
end

ARGV.clear
Karafka::App.config.internal.routing.activity_manager.clear

assert_equal 3, guarded.size

ARGV[0] = 'server'
ARGV[1] = '--subscription-groups'
ARGV[2] = 'non-existing'

begin
  Karafka::Cli.start
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?('cli.include_subscription_groups')
  assert e.message.include?('Unknown subscription group name')

  guarded << true
end

ARGV.clear
Karafka::App.config.internal.routing.activity_manager.clear

assert_equal 4, guarded.size

ARGV[0] = 'server'
ARGV[1] = '--topics'
ARGV[2] = 'non-existing'

begin
  Karafka::Cli.start
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?('cli.include_topics')
  assert e.message.include?('Unknown topic name')

  guarded << true
end

ARGV.clear
Karafka::App.config.internal.routing.activity_manager.clear

assert_equal 5, guarded.size
