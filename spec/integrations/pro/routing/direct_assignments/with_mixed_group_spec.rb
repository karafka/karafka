# frozen_string_literal: true

# We should not be allowed to mix automatic and direct assignments

setup_karafka

failed = false

begin
  draw_routes(create_topics: false) do
    topic :a do
      consumer Class.new
      assign(0)
    end

    topic :b do
      consumer Class.new
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed

Karafka::App.routes.clear

failed = false

begin
  draw_routes(create_topics: false) do
    consumer_group :a do
      topic :a do
        consumer Class.new
        assign(0)
      end
    end

    topic :b do
      consumer Class.new
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

# Should be ok when separate CGs
assert !failed

Karafka::App.routes.clear

failed = false

begin
  draw_routes(create_topics: false) do
    subscription_group :a do
      topic :a do
        consumer Class.new
        assign(0)
      end
    end

    topic :b do
      consumer Class.new
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

# Should not be ok when separate SGs in a CG
assert failed
