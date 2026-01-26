# frozen_string_literal: true

# Karafka should not allow for multiple subscriptions to the same topic in the same consumer group
# even if subscription group names are different

setup_karafka

failed = false

begin
  draw_routes(create_topics: false) do
    consumer_group :test do
      subscription_group "namespace_collision" do
        topic :test do
          consumer Class.new
        end
      end

      subscription_group "namespace_collision2" do
        topic :test do
          consumer Class.new
        end
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed
