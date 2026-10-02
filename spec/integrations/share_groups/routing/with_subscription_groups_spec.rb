# frozen_string_literal: true

# Karafka should support all the subscription groups definition styles inside share groups
# (KIP-932): block based, symbol based and nameless (default) ones, in any order. Each
# subscription group is a separate share consumer of the same share group (same group.id).

setup_karafka

Consumer = Class.new(Karafka::ShareConsumer)

draw_routes(create_topics: false) do
  share_group "sg" do
    topic "t0" do
      consumer Consumer
    end

    subscription_group :symbol_based do
      topic "t1" do
        consumer Consumer
      end
    end

    subscription_group "block_based" do
      topic "t2" do
        consumer Consumer
      end

      topic "t3" do
        consumer Consumer
      end
    end

    subscription_group do
      topic "t4" do
        consumer Consumer
      end
    end

    topic "t5" do
      consumer Consumer
    end
  end
end

sgs = Karafka::App.routes.share_groups.first.subscription_groups

assert_equal [%w[t0], %w[t1], %w[t2 t3], %w[t4], %w[t5]], sgs.map { |sg| sg.topics.map(&:name) }
assert_equal "symbol_based", sgs[1].name
assert_equal "block_based", sgs[2].name
# Nameless subscription groups and topics outside of subscription groups get generated names
assert_equal 5, sgs.map(&:name).uniq.size

assert_equal 1, sgs.map { |sg| sg.kafka.fetch(:"group.id") }.uniq.size
assert_equal "sg", sgs.first.kafka.fetch(:"group.id")
assert sgs.all? { |sg| sg.group.share_group? }
assert_equal sgs.size, sgs.map(&:id).uniq.size
