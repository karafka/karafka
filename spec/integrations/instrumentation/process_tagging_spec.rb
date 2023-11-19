# frozen_string_literal: true

# We should have abilities to tag process with whatever info we want

setup_karafka

::Karafka::Process.tags.add(:commit_hash, '#4f0450221')

assert_equal ::Karafka::Process.tags.to_a, %w[#4f0450221]
