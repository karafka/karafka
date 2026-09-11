# frozen_string_literal: true

# When the routing describes an active share group, swarm mode must fail fast in the supervisor
# before any node is forked, with the share-groups-not-implemented error. Before the fix each
# forked node would crash on the guard and the supervisor would restart it in an endless loop.

setup_karafka

draw_routes(create_topics: false) do
  consumer_group "cg" do
    topic "regular" do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  share_group "sg" do
    topic "share-topic" do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

ARGV[0] = "swarm"

guarded = []

begin
  Karafka::Cli.start
rescue Karafka::Errors::ShareGroupsNotImplementedError => e
  assert e.message.include?("sg"), e.message

  guarded << true
end

ARGV.clear

assert_equal 1, guarded.size
