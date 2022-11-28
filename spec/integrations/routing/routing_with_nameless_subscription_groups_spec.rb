# frozen_string_literal: true

# Karafka should allow for nameless subscription groups inside of consumer groups

setup_karafka

draw_routes do
  consumer_group :test do
    subscription_group do
      topic 'topic1' do
        consumer Class.new
      end
    end

    subscription_group do
      topic 'topic2' do
        consumer Class.new
      end
    end
  end

  subscription_group do
    topic 'topic3' do
      consumer Class.new
    end
  end
end

# Nothing needed. If something would be off, would fail.
