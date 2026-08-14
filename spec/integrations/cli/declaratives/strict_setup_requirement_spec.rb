# frozen_string_literal: true

# When we have strict_declarative_topics set to true, we should ensure all non-pattern definitions
# of topics have their declarative references. Declarative definitions now live independently in the
# declaratives repository, so a routed topic is "covered" only when it has an active declaration
# there.

setup_karafka do |config|
  config.strict_declarative_topics = true
end

ARGV[0] = "info"

# @param valid [Boolean] whether strict validation is expected to pass
# @param declaratives [Hash] topic name => active flag to declare before drawing routes
# @param block [Proc] routing definition
def draw_and_validate(valid:, declaratives: {}, &block)
  guarded = false

  declaratives.each do |name, active|
    Karafka::App.declaratives.draw do
      topic(name) { active(active) }
    end
  end

  begin
    draw_routes(create_topics: false) do
      instance_eval(&block)
    end

    Karafka::Cli.start
  rescue Karafka::Errors::InvalidConfigurationError
    guarded = true
  end

  valid ? assert(!guarded) : assert(guarded)

  clear_app_draws
end

# 'a' is routed but has no declarative definition -> strict validation guards
draw_and_validate(valid: false) do
  topic "a" do
    consumer Class.new
  end
end

# 'a' is routed and declared active -> ok
draw_and_validate(valid: true, declaratives: { "a" => true }) do
  topic "a" do
    consumer Class.new
  end
end

# 'a' is declared but its DLQ 'dlq' is not -> strict validation guards
draw_and_validate(valid: false, declaratives: { "a" => true }) do
  topic "a" do
    consumer Class.new
    dead_letter_queue(topic: "dlq")
  end
end

# both 'a' and its DLQ 'dlq' are declared active -> ok
draw_and_validate(valid: true, declaratives: { "a" => true, "dlq" => true }) do
  topic "a" do
    consumer Class.new
    dead_letter_queue(topic: "dlq")
  end
end

# 'dlq' is declared inactive (opted out of management) -> strict validation guards
draw_and_validate(valid: false, declaratives: { "a" => true, "dlq" => false }) do
  topic "a" do
    consumer Class.new
    dead_letter_queue(topic: "dlq")
  end
end

# When strict declaratives is off, an inactive/missing declaration is acceptable
Karafka::App.config.strict_declarative_topics = false

draw_and_validate(valid: true, declaratives: { "a" => true, "dlq" => false }) do
  topic "a" do
    consumer Class.new
    dead_letter_queue(topic: "dlq")
  end
end
