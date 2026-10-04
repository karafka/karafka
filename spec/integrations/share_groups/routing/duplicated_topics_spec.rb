# frozen_string_literal: true

# Karafka should not allow for subscribing to the same topic more than once within a single share
# group (KIP-932): neither within one subscription group, nor across different subscription groups
# nor when the share group is reopened in another draw. The same topic can however be used by
# different share groups and by a consumer group at the same time.

setup_karafka

Consumer = Class.new(Karafka::ShareConsumer)

def expect_duplication_error
  failed = false

  begin
    yield
  rescue Karafka::Errors::InvalidConfigurationError => e
    assert e.message.include?("routes.sg.topics"), e.message

    failed = true
  end

  assert failed

  clear_app_draws
end

expect_duplication_error do
  draw_routes(create_topics: false) do
    share_group "sg" do
      topic "t" do
        consumer Consumer
      end

      topic "t" do
        consumer Consumer
      end
    end
  end
end

expect_duplication_error do
  draw_routes(create_topics: false) do
    share_group "sg" do
      subscription_group "a" do
        topic "t" do
          consumer Consumer
        end
      end

      subscription_group "b" do
        topic "t" do
          consumer Consumer
        end
      end
    end
  end
end

expect_duplication_error do
  draw_routes(create_topics: false) do
    share_group "sg" do
      topic "t" do
        consumer Consumer
      end
    end
  end

  draw_routes(create_topics: false) do
    share_group "sg" do
      topic "t" do
        consumer Class.new(Karafka::ShareConsumer)
      end
    end
  end
end

# The same topic in many groups of any type is fine
draw_routes(create_topics: false) do
  share_group "sg1" do
    topic "t" do
      consumer Consumer
    end
  end

  share_group "sg2" do
    topic "t" do
      consumer Consumer
    end
  end

  consumer_group "cg" do
    topic "t" do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

assert_equal 3, Karafka::App.routes.size
