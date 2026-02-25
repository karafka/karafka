# frozen_string_literal: true

# When declarative topic exists but has more partitions than declared, we should just inform that
# such change is not supported and will be ignored

setup_karafka

Karafka::Admin.create_topic(DT.topic, 5, 1)

draw_routes(create_topics: false) do
  topic DT.topic do
    active false
    config(partitions: 2)
  end
end

ARGV[0] = "topics"
ARGV[1] = "plan"

results = capture_stdout do
  Karafka::Cli.start
end

assert !results.include?("Following topics will have configuration changes:")
assert !results.include?("perform any actions. No changes needed.")
assert !results.include?("Following topics will be created:")
assert !results.include?("Following topics will be repartitioned:")
assert results.include?(
  "Following topics repartitioning will be ignored as downscaling is not supported:"
)
assert results.include?(DT.topics[0])
assert !results.include?(DT.topics[1])
