# frozen_string_literal: true

# Share consumers (KIP-932) do not support pattern subscriptions, so regexp-style topic
# definitions inside share groups must be rejected by the share topic contract with a clear
# error, instead of a Regexp being silently stringified into a nonsense literal name or a "^"
# pattern string failing only with the generic name-format message. This prevents users from
# accidentally assuming regexp subscriptions work for share groups. Consumer groups are
# unaffected.

setup_karafka

# A Regexp topic reference in a share group must be rejected with a clear error
failed = false

begin
  draw_routes(create_topics: false) do
    share_group "sg-regexp" do
      topic(/events.*/) do
        active(false)
        consumer Class.new(Karafka::BaseConsumer)
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?("not supported for share groups"), e.message

  failed = true
end

assert failed

clear_app_draws

# A librdkafka-style "^" pattern string must be rejected the same way
failed = false

begin
  draw_routes(create_topics: false) do
    share_group "sg-caret" do
      topic("^events-.*") do
        active(false)
        consumer Class.new(Karafka::BaseConsumer)
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?("not supported for share groups"), e.message

  failed = true
end

assert failed

clear_app_draws

# Regular explicit topic names keep working in share groups
draw_routes(create_topics: false) do
  share_group "sg-ok" do
    topic "events" do
      active(false)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

assert_equal 1, Karafka::App.routes.share_groups.size
assert_equal "events", Karafka::App.routes.share_groups.first.topics.first.name
