# frozen_string_literal: true

require 'karafka/pro/routing/builder_extensions'
require 'karafka/pro/routing/topic_extensions'
require 'karafka/pro/contracts/base'
require 'karafka/pro/contracts/topic'
require 'karafka/pro/base_consumer'

RSpec.describe_current do
  subject(:extended_builder) do
    Karafka::Routing::Builder.new.tap do |builder|
      builder.singleton_class.prepend Karafka::Pro::Routing::BuilderExtensions
    end
  end

  context 'when defining a topic in a valid way' do
    let(:building) do
      extended_builder.draw do
        topic('test') do
          consumer Class.new(Karafka::Pro::BaseConsumer)
          target.singleton_class.prepend Karafka::Pro::Routing::TopicExtensions
        end
      end
    end

    it 'expect not to raise errors' do
      expect { building }.not_to raise_error
    end
  end

  context 'when defining a topic in an invalid way' do
    let(:building) do
      extended_builder.draw do
        topic('test') do
          consumer Class.new(Karafka::BaseConsumer)
          target.singleton_class.prepend Karafka::Pro::Routing::TopicExtensions
        end
      end
    end

    it 'expect not to raise errors' do
      expect { building }.to raise_error(Karafka::Errors::InvalidConfigurationError)
    end
  end
end
