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
  subject(:validation) { described_class.new.call(config) }

  let(:config) do
    {
      swarm: {
        active: true,
        nodes: nodes
      }
    }
  end

  context 'when configuration is valid' do
    let(:nodes) { 0...Karafka::App.config.swarm.nodes }

    it 'passes validation' do
      expect(validation).to be_success
    end
  end

  context 'when active is not true' do
    let(:nodes) { 0...Karafka::App.config.swarm.nodes }

    before { config[:swarm][:active] = false }

    it 'fails validation' do
      expect(validation).not_to be_success
    end
  end

  context 'when nodes is not a Range or Array of Integers' do
    let(:nodes) { %w[invalid nodes] }

    it 'fails validation' do
      expect(validation).not_to be_success
    end
  end

  context 'when nodes array contains non-integer values' do
    let(:nodes) { [1, 'two', 3] }

    it 'fails validation' do
      expect(validation).not_to be_success
    end
  end

  context 'when nodes hash contains non-integer nodes' do
    let(:nodes) { { 'test' => [1] } }

    it 'fails validation' do
      expect(validation).not_to be_success
    end
  end

  context 'when nodes hash contains non array partitions' do
    let(:nodes) { { 0 => 'test' } }

    it 'fails validation' do
      expect(validation).not_to be_success
    end
  end

  context 'when nodes hash contains array partitions with invalid partitions' do
    let(:nodes) { { 0 => ['test'] } }

    it 'fails validation' do
      expect(validation).not_to be_success
    end
  end

  context 'when nodes hash contains array partitions with valid partitions' do
    let(:nodes) { { 0 => [0, 1] } }

    it { expect(validation).to be_success }
  end

  context 'when nodes hash contains array partitions with valid partitions range' do
    let(:nodes) { { 0 => 0..2 } }

    it { expect(validation).to be_success }
  end

  context 'when nodes hash contains unreachable node' do
    let(:nodes) { { 1_000 => [0, 1] } }

    it { expect(validation).not_to be_success }
  end

  context 'when range of nodes does not match any existing node' do
    let(:nodes) { 100...200 }

    it 'fails validation due to non-existent nodes' do
      expect(validation).not_to be_success
    end
  end

  context 'with valid range fitting number of nodes' do
    let(:nodes) { 0...2 }

    it 'passes validation' do
      expect(validation).to be_success
    end
  end

  context 'with an infinite range' do
    let(:nodes) { 0...Float::INFINITY }

    it 'passes validation' do
      expect(validation).to be_success
    end
  end
end
