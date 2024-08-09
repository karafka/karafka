# frozen_string_literal: true

# When working with Admin API in post-forks we should have no issues.
# @see https://github.com/ffi/ffi/issues/1114

setup_karafka

# We need this here so we have all callbacks loaded in the parent
Karafka::Admin.create_topic(SecureRandom.uuid, 1, 1)

pids = Array.new(3) do
  fork do
    name = SecureRandom.uuid

    Karafka::Admin.create_topic(name, 1, 1)

    Karafka::Admin::Configs.describe(
      Karafka::Admin::Configs::Resource.new(
        type: :topic,
        name: name
      )
    )
  end
end

# Should finish. If anything is off with the callbacks, will hang
pids.each { |pid| Process.wait(pid) }
