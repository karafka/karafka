# frozen_string_literal: true

# karafka topics delete should work and not fail when no topics are defined

setup_karafka

ARGV[0] = "topics"
ARGV[1] = "delete"

Karafka::Cli.start
