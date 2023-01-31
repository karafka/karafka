# frozen_string_literal: true

# Karafka should fail when excluding non existing routing elements

setup_karafka

guarded = []

begin
  draw_routes do
    consumer_group 'regular' do
      topic '#$%^&*(' do
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << true
end

Karafka::App.routes.clear

begin
  draw_routes do
    consumer_group '#$%^&*(' do
      topic 'regular' do
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << true
end

ARGV[0] = 'server'
ARGV[1] = '--exclude-consumer-groups'
ARGV[2] = 'non-existing'

Karafka::Cli.prepare

begin
  Karafka::Cli.start
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?('Unknown consumer group name')

  guarded << true
end

ARGV.clear
Karafka::App.config.internal.routing.activity_manager.clear

assert_equal 3, guarded.size

ARGV[0] = 'server'
ARGV[1] = '--exclude-subscription-groups'
ARGV[2] = 'non-existing'

Karafka::Cli.prepare

begin
  Karafka::Cli.start
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?('Unknown subscription group name')

  guarded << true
end

ARGV.clear
Karafka::App.config.internal.routing.activity_manager.clear

assert_equal 4, guarded.size

ARGV[0] = 'server'
ARGV[1] = '--exclude-topics'
ARGV[2] = 'non-existing'

Karafka::Cli.prepare

begin
  Karafka::Cli.start
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?('Unknown topic name')

  guarded << true
end

ARGV.clear
Karafka::App.config.internal.routing.activity_manager.clear

assert_equal 5, guarded.size
