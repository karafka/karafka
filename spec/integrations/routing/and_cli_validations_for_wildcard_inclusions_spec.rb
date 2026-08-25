# frozen_string_literal: true

# Companion to `and_cli_validations_for_inclusions_spec` but for wildcard values. A literal
# include value that matches no route is rejected with an "Unknown ... name" error. A wildcard
# value instead skips that existence check (it may legitimately match consumer groups,
# subscription groups or topics that do not exist on this process yet), so it must NOT raise the
# "Unknown ..." error. When such a wildcard matches nothing, the server still refuses to boot -
# but via the "No topics to subscribe to" guard rather than the existence check.

setup_karafka

draw_routes(create_topics: false) do
  consumer_group "app-a" do
    subscription_group "sg-a" do
      topic "topic-a" do
        consumer Class.new
      end
    end
  end
end

activity_manager = Karafka::App.config.internal.routing.activity_manager

guarded = []

ARGV[0] = "server"
ARGV[1] = "--consumer-groups"
ARGV[2] = "nonexistent-*"

begin
  Karafka::Cli.start
rescue Karafka::Errors::InvalidConfigurationError => e
  assert !e.message.include?("Unknown consumer group name")
  assert e.message.include?("No topics to subscribe to")
  guarded << true
end

ARGV.clear
activity_manager.clear

ARGV[0] = "server"
ARGV[1] = "--subscription-groups"
ARGV[2] = "nonexistent-*"

begin
  Karafka::Cli.start
rescue Karafka::Errors::InvalidConfigurationError => e
  assert !e.message.include?("Unknown subscription group name")
  assert e.message.include?("No topics to subscribe to")
  guarded << true
end

ARGV.clear
activity_manager.clear

ARGV[0] = "server"
ARGV[1] = "--topics"
ARGV[2] = "nonexistent-*"

begin
  Karafka::Cli.start
rescue Karafka::Errors::InvalidConfigurationError => e
  assert !e.message.include?("Unknown topic name")
  assert e.message.include?("No topics to subscribe to")
  guarded << true
end

ARGV.clear
activity_manager.clear

assert_equal 3, guarded.size
