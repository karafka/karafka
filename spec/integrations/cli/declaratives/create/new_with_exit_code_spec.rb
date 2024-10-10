# frozen_string_literal: true

# karafka topics create should exit with 2 when new topics are created and detailed exit codes are
# turned on

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

# Don't use the specs topics auto-bootstrap feature
# We disable it because we want to test the CLI action for this
draw_routes(create_topics: false) do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    config(
      partitions: 2,
      'cleanup.policy': 'compact'
    )

    consumer Consumer
  end
end

ARGV[0] = 'topics'
ARGV[1] = 'create'
ARGV[2] = '--detailed_exitcode'

Karafka::Cli.start
