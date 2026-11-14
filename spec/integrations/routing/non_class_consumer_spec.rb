# frozen_string_literal: true

# A topic consumer that is neither a Class nor a String/Symbol name (e.g. a consumer instance or
# an Integer) should fail routing validation at draw time instead of failing on the first message.

setup_karafka

consumer_class = Class.new(Karafka::BaseConsumer)

[consumer_class.new, 123].each do |invalid_consumer|
  clear_app_draws
  message = nil

  begin
    draw_routes(create_topics: false) do
      topic "non_class_consumer" do
        consumer invalid_consumer
      end
    end
  rescue Karafka::Errors::InvalidConfigurationError => e
    message = e.message
  end

  assert message.to_s.include?("needs to be a consumer class or its name"), message
end
