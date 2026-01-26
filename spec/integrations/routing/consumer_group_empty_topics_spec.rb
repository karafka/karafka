# frozen_string_literal: true

# Karafka should detect and reject consumer groups with no topics defined

setup_karafka

failed = false

begin
  draw_routes(create_topics: false) do
    subscription_group do
      # No topics defined - this should fail validation
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed, "Should have raised InvalidConfigurationError for empty subscription group"
