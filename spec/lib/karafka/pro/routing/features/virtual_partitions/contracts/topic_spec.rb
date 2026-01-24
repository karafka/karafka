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
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      virtual_partitions: {
        active: true,
        partitioner: ->(_) { 1 },
        reducer: ->(_) { 1 },
        max_partitions: 2,
        offset_metadata_strategy: :exact,
        distribution: :consistent
      },
      manual_offset_management: {
        active: mom_active
      },
      active_job: {
        active: aj_active
      }
    }
  end

  let(:mom_active) { false }
  let(:aj_active) { false }
  let(:tags) { [] }

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when virtual partitions max_partitions is too low' do
    before { config[:virtual_partitions][:max_partitions] = 0 }

    it { expect(check).not_to be_success }
  end

  context 'when virtual partitions offset_metadata_strategy is not a symbol' do
    before { config[:virtual_partitions][:offset_metadata_strategy] = 0 }

    it { expect(check).not_to be_success }
  end

  context 'when virtual partitions are active but no partitioner' do
    before { config[:virtual_partitions][:partitioner] = nil }

    it { expect(check).not_to be_success }
  end

  context 'when there is no reducer' do
    before { config[:virtual_partitions][:reducer] = nil }

    it { expect(check).not_to be_success }
  end

  context 'when distribution is not a valid value' do
    before { config[:virtual_partitions][:distribution] = :invalid }

    it { expect(check).not_to be_success }
  end

  context 'when distribution is consistent' do
    before { config[:virtual_partitions][:distribution] = :consistent }

    it { expect(check).to be_success }
  end

  context 'when distribution is balanced' do
    before { config[:virtual_partitions][:distribution] = :balanced }

    it { expect(check).to be_success }
  end

  context 'when manual offset management is on with virtual partitions for active job' do
    let(:mom_active) { true }
    let(:aj_active) { true }

    it { expect(check).to be_success }
  end
end
