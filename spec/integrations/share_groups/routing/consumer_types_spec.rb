# frozen_string_literal: true

# Share group (KIP-932) topics must be consumed by share consumers and consumer group topics by
# consumer group consumers. Mixing them up must be rejected during routing validation. Active
# share topics need a consumer while inactive ones (for example used only via the admin API) may
# be defined without one.

setup_karafka

failed = []

# A consumer group consumer wired into a share group
begin
  draw_routes(create_topics: false) do
    share_group "sg" do
      topic "t" do
        consumer Class.new(Karafka::BaseConsumer)
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?("Karafka::ShareConsumer"), e.message

  failed << :base_in_share
end

clear_app_draws

# A share consumer wired into a consumer group
begin
  draw_routes(create_topics: false) do
    consumer_group "cg" do
      topic "t" do
        consumer Class.new(Karafka::ShareConsumer)
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?("Karafka::BaseConsumer"), e.message

  failed << :share_in_consumer
end

clear_app_draws

# An active share topic without any consumer
begin
  draw_routes(create_topics: false) do
    share_group "sg" do
      topic "t" do
        active(true)
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?("routes.sg.t.consumer"), e.message

  failed << :missing
end

clear_app_draws

assert_equal %i[base_in_share share_in_consumer missing], failed

# Inactive share topics do not need a consumer
draw_routes(create_topics: false) do
  share_group "sg" do
    topic "t" do
      active(false)
    end
  end
end

assert_equal 1, Karafka::App.routes.share_groups.size

clear_app_draws

# A share consumer subclass is accepted
ApplicationShareConsumer = Class.new(Karafka::ShareConsumer)

draw_routes(create_topics: false) do
  share_group "sg" do
    topic "t" do
      consumer Class.new(ApplicationShareConsumer)
    end
  end
end

assert Karafka::App.routes.share_groups.first.topics.first.consumer < Karafka::ShareConsumer
