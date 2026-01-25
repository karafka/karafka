# frozen_string_literal: true

# Karafka CLI should work and should not fail

ARGV[0] = "info"

Karafka::Cli.start
