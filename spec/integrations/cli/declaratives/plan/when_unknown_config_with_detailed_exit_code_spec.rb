# frozen_string_literal: true

# karafka topics plan with detailed exit code should exit with 1 (error) and not 2 (changes) when
# an existing topic has configuration unknown to the cluster

setup_karafka

Karafka::Admin.create_topic(DT.topic, 1, 1)

draw_routes(create_topics: false) do
  topic DT.topic do
    active false
    config(
      partitions: 1,
      "retention.msx": 86_400_000
    )
  end
end

ARGV[0] = "topics"
ARGV[1] = "plan"
ARGV[2] = "--detailed-exitcode"

results = capture_stdout do
  Karafka::Cli.start
rescue SystemExit => e
  DT[:status] = e.status
end

assert_equal 1, DT[:status]
assert results.include?('retention.msx: "86400000"')
assert !results.include?("Following topics will have configuration changes:")
assert !results.include?("No changes needed.")
