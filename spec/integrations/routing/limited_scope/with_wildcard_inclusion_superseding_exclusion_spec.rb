# frozen_string_literal: true

# When the same topic matches both a wildcard inclusion and a wildcard exclusion, inclusion wins
# (this mirrors the documented literal behavior where inclusion supersedes exclusion). Topics
# that only match the exclusion, or match neither, stay inactive because an inclusion list is
# present.

setup_karafka

draw_routes(create_topics: false) do
  topic "shared-a" do
    consumer Class.new
  end

  topic "shared-b" do
    consumer Class.new
  end

  topic "other-a" do
    consumer Class.new
  end
end

activity_manager = Karafka::App.config.internal.routing.activity_manager
activity_manager.include(:topics, "shared-*")
activity_manager.exclude(:topics, "shared-*")

active = Karafka::App
  .subscription_groups
  .values
  .flatten
  .flat_map { |sg| sg.topics.map(&:name) }
  .uniq
  .sort

# Both shared topics match include and exclude - inclusion supersedes, so they stay active.
# `other-a` matches neither and is dropped because an inclusion list is present.
assert_equal %w[shared-a shared-b], active
