# frozen_string_literal: true

# @see https://github.com/karafka/karafka/issues/2344
# @see https://github.com/flipp-oss/deimos
# @see https://github.com/flipp-oss/deimos/blob/fc89c645/lib/deimos/ext/routing_defaults.rb
#
# This is to ensure that Deimos routing patches work as expected

setup_karafka do |config|
  config.kafka = {
    'bootstrap.servers': 'something.super',
    'max.poll.interval.ms': 1_000
  }
end

class Matcher
  def initialize
    @applications = []
  end

  def replay_on(topic_node)
    @applications.each do |method, kwargs|
      if method == :kafka
        topic_node.kafka = kwargs.is_a?(Array) ? kwargs[0] : kwargs
        next
      end
      if kwargs.is_a?(Hash)
        ref = topic_node.public_send(method)

        kwargs.each do |arg, val|
          if ref.respond_to?("#{arg}=")
            ref.public_send("#{arg}=", val)
          elsif ref.respond_to?(:details)
            ref.details.merge!(kwargs)
          elsif ref.is_a?(Hash)
            ref.merge!(kwargs)
          else
            raise 'No idea if such case exists, if so, similar handling as config'
          end
        end
      end

      if kwargs.is_a?(Array) && kwargs.size == 1
        if topic_node.respond_to?("#{method}=")
          topic_node.public_send(:"#{method}=", kwargs.first)
        else
          topic_node.public_send(method, *kwargs)
        end
      end
    end
  end

  def method_missing(method_name, *args, **kwargs)
    @applications << if args.empty?
                       [method_name, kwargs]
                     else
                       [method_name, args]
                     end
  end

  def respond_to_missing?(_method_name, _include_private = false)
    true
  end
end

DEFAULTS = Matcher.new

module Builder
  def defaults(&block)
    DEFAULTS.instance_eval(&block) if block
  end
end

module ConsumerGroup
  def topic=(name, &block)
    k = Matcher.new
    t = super(name)
    k.instance_eval(&block) if block
    DEFAULTS.replay_on(t)
    k.replay_on(t)
  end
end

Karafka::Routing::Builder.prepend Builder
Karafka::Routing::ConsumerGroup.prepend ConsumerGroup

draw_routes(create_topics: false) do
  defaults do
    dead_letter_queue(
      topic: 'dead_messages',
      max_retries: 2,
      independent: false,
      mark_after_dispatch: true
    )
  end

  topic 'test' do
    active(false)
    dead_letter_queue(
      topic: 'dead_messages2'
    )
  end
end

dlq_config = Karafka::App.routes.first.topics.first.dead_letter_queue

assert_equal dlq_config.topic, 'dead_messages2'
assert_equal dlq_config.max_retries, 2
assert_equal dlq_config.independent, false
