# frozen_string_literal: true

# Karafka should allow for nice subscription groups management style with symbols.

setup_karafka

failed = false

begin
  draw_routes do
    subscription_group :group1 do
      topic :topic1 do
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert !failed

begin
  draw_routes do
    subscription_group do
      topic :topic2 do
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert !failed
