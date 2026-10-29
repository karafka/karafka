# frozen_string_literal: true

# Karafka should fail if we specify a share group that was not defined (both for inclusions and
# exclusions) also when working in the swarm mode, before the share groups swarm guard kicks in.

setup_karafka

guarded = []

draw_routes(create_topics: false) do
  consumer_group "existing-cg" do
    topic "regular" do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  share_group "existing-sg" do
    topic "share-topic" do
      consumer Class.new(Karafka::ShareConsumer)
    end
  end
end

%w[--include-share-groups --exclude-share-groups].each do |flag|
  ARGV.replace(["swarm", flag, "non-existing"])

  begin
    Karafka::Cli.start
  rescue Karafka::Errors::InvalidConfigurationError => e
    assert e.message.include?("Unknown share group name"), e.message

    guarded << true
  end

  Karafka::App.config.internal.routing.activity_manager.clear
end

ARGV.clear

assert_equal 2, guarded.size
