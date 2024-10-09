# frozen_string_literal: true

# When we have strict_declarative_topics set to true, we should ensure all non-pattern definitions
# of topics have their declarative references

setup_karafka do |config|
  config.strict_declarative_topics = true
end

ARGV[0] = 'info'

def draw_and_validate(valid:, &block)
  guarded = false

  begin
    draw_routes(create_topics: false) do
      instance_eval(&block)
    end

    Karafka::Cli.start
  rescue Karafka::Errors::InvalidConfigurationError
    guarded = true
  end

  valid ? assert(!guarded) : assert(guarded)

  Karafka::App.routes.clear
end

draw_and_validate(valid: false) do
  topic 'a' do
    consumer Class.new
    config(active: false)
  end
end

draw_and_validate(valid: true) do
  topic 'a' do
    consumer Class.new
  end
end

draw_and_validate(valid: false) do
  topic 'a' do
    consumer Class.new
    dead_letter_queue(topic: 'dlq')
  end
end

draw_and_validate(valid: true) do
  topic 'a' do
    consumer Class.new
    dead_letter_queue(topic: 'dlq')
  end

  topic 'dlq' do
    active(false)
  end
end

draw_and_validate(valid: false) do
  topic 'a' do
    consumer Class.new
    dead_letter_queue(topic: 'dlq')
  end

  topic 'dlq' do
    active(false)
    config(active: false)
  end
end

draw_and_validate(valid: false) do
  pattern(/a/) do
    consumer Class.new
    dead_letter_queue(topic: 'dlq')
  end

  topic 'dlq' do
    active(false)
    config(active: false)
  end
end

draw_and_validate(valid: false) do
  pattern(/a/) do
    consumer Class.new
    dead_letter_queue(topic: 'dlq')
  end
end

draw_and_validate(valid: true) do
  pattern(/a/) do
    consumer Class.new
  end
end

draw_and_validate(valid: true) do
  pattern('a', /a/) do
    consumer Class.new
  end
end

# When no strict declaratives
Karafka::App.config.strict_declarative_topics = false

draw_and_validate(valid: true) do
  topic 'a' do
    consumer Class.new
    dead_letter_queue(topic: 'dlq')
  end

  topic 'dlq' do
    active(false)
    config(active: false)
  end
end
