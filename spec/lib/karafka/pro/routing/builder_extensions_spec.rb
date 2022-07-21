# frozen_string_literal: true

require 'karafka/pro/routing/builder_extensions'
require 'karafka/pro/routing/topic_extensions'
require 'karafka/pro/contracts/base'
require 'karafka/pro/contracts/consumer_group'
require 'karafka/pro/contracts/consumer_group_topic'
require 'karafka/pro/base_consumer'

RSpec.describe_current do
  subject(:extended_builder) do
    Karafka::Routing::Builder.new.tap do |builder|
      builder.singleton_class.prepend Karafka::Pro::Routing::BuilderExtensions
    end
  end

  context 'when defining a topic in a valid way' do
    it 'expect not to raise errors' do
      expect do
        extended_builder.draw do
          topic('test') { consumer Class.new(Karafka::Pro::BaseConsumer) }
        end
      end.not_to raise_error
    end
  end

  context 'when defining a topic in an invalid way' do
    it 'expect not to raise errors' do
      expect do
        extended_builder.draw do
          topic('test') { consumer Class.new(Karafka::BaseConsumer) }
        end
      end.to raise_error(Karafka::Errors::InvalidConfigurationError)
    end
  end
end
