# frozen_string_literal: true

# Karafka should fail if we specify a consumer group that was not defined also when working in the
# swarm mode.

setup_karafka

guarded = []

draw_routes(create_topics: false) do
  consumer_group 'existing' do
    topic 'regular' do
      consumer Class.new
    end
  end
end

ARGV[0] = 'swarm'
ARGV[1] = '--consumer-groups'
ARGV[2] = 'non-existing'

begin
  Karafka::Cli.start
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?('Unknown consumer group name')

  guarded << true
end

ARGV.clear
assert_equal 1, guarded.size
