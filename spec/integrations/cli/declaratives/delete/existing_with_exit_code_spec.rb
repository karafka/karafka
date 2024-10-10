# frozen_string_literal: true

# karafka topics delete with detailed exit code should exit with 2 when cli runs with detailed
# flag. We check this in the exit code definitions for integrations

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    consumer Consumer
  end
end

ARGV[0] = 'topics'
ARGV[1] = 'delete'
ARGV[2] = '--detailed-exitcode'

Karafka::Cli.start
