# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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
