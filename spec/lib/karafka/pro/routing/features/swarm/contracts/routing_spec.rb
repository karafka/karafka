# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:validation) { described_class.new.validate!(builder) }

  let(:builder) { Karafka::App.config.internal.routing.builder.class.new }
  let(:validation_error) { Karafka::Errors::InvalidConfigurationError }

  after { builder.clear }

  context 'when there are no routes defined' do
    before { builder.clear }

    it { expect { validation }.to raise_error(validation_error) }
  end

  context 'when routes do not match all the topics' do
    before do
      builder.draw do
        topic 'topic1' do
          consumer Class.new(Karafka::BaseConsumer)
          swarm(nodes: 1..)
        end
      end
    end

    it { expect { validation }.to raise_error(validation_error) }
  end

  context 'when routes in hash do not match all the topics' do
    before do
      builder.draw do
        topic 'topic1' do
          consumer Class.new(Karafka::BaseConsumer)
          swarm(nodes: { 1 => [0, 2] })
        end
      end
    end

    it { expect { validation }.to raise_error(validation_error) }
  end

  context 'when routes hash matches all the topics' do
    before do
      builder.draw do
        topic 'topic1' do
          consumer Class.new(Karafka::BaseConsumer)
          swarm(nodes: { 0 => [0], 1 => [1], 2 => [2] })
        end
      end
    end

    it { expect { validation }.not_to raise_error }
  end

  context 'when routes match all the topics' do
    before do
      builder.draw do
        topic 'topic1' do
          consumer Class.new(Karafka::BaseConsumer)
          swarm(nodes: 0..)
        end
      end
    end

    it { expect { validation }.not_to raise_error }
  end

  context 'when routes match multiple topics' do
    before do
      builder.draw do
        active_consumer = Class.new(Karafka::BaseConsumer)

        topic 'topic1' do
          consumer active_consumer
          swarm(nodes: 2..100)
        end

        topic 'topic2' do
          consumer active_consumer
          swarm(nodes: [1])
        end

        topic 'topic3' do
          consumer active_consumer
          swarm(nodes: [0, 2])
        end
      end
    end

    it { expect { validation }.not_to raise_error }
  end
end
