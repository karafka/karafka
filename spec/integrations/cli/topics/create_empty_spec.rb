# frozen_string_literal: true

# karafka topics create should work and not fail when no topics are defined

setup_karafka

Karafka::Cli.prepare

Karafka::Cli.start %w[topics create]
