# frozen_string_literal: true

# When we try to use invalid admin configuration, it should fail

guarded = []

begin
  setup_karafka do |config|
    config.admin.retry_backoff = -1
  end

  draw_routes do
    consumer_group "usual" do
      topic "regular" do
        consumer Class.new
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  guarded << true
end

assert_equal [true], guarded
