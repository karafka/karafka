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
  subject(:limiter) { described_class.new(manager, collapser) }

  4.times { |i| let(:"message#{i + 1}") { build(:messages_message) } }

  let(:messages) { [message1, message2, message3, message4] }
  let(:collapser) { Karafka::Pro::Processing::Collapser.new }
  let(:manager) do
    Karafka::Pro::Processing::Coordinators::VirtualOffsetManager.new('topic', 0, :exact)
  end

  before { manager.register(messages.map(&:offset)) }

  context 'when not collapsed' do
    it 'expect not to filter anything' do
      expect { limiter.apply!(messages) }.not_to(change { messages })
    end
  end

  context 'when collapsed' do
    before do
      collapser.collapse_until!(messages.last.offset)
      collapser.refresh!(messages.first.offset)
    end

    context 'when nothing marked' do
      it { expect { limiter.apply!(messages) }.not_to(change { messages }) }
    end

    context 'when all marked' do
      before { manager.mark_until(messages.last, nil) }

      it 'expect to remove all' do
        limiter.apply!(messages)
        expect(messages).to eq([])
      end
    end

    context 'when some marked' do
      before do
        manager.mark(messages[0], nil)
        manager.mark(messages[1], nil)
      end

      it 'expect to remove non-marked' do
        limiter.apply!(messages)
        expect(messages).to eq([message3, message4])
      end
    end
  end
end
