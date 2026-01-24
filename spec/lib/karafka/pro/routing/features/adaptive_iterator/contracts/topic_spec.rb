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
      adaptive_iterator: {
        active: true,
        safety_margin: 15,
        clean_after_yielding: true,
        marking_method: :mark_as_consumed
      },
      virtual_partitions: {
        active: false
      },
      long_running_job: {
        active: false
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when safety_margin is not an integer' do
    before { config[:adaptive_iterator][:safety_margin] = 'invalid_margin' }

    it { expect(check).not_to be_success }
  end

  context 'when safety_margin is not positive' do
    before { config[:adaptive_iterator][:safety_margin] = -5 }

    it { expect(check).not_to be_success }
  end

  context 'when safety_margin is 100 or more' do
    before { config[:adaptive_iterator][:safety_margin] = 100 }

    it { expect(check).not_to be_success }
  end

  context 'when marking_method is not a valid symbol' do
    before { config[:adaptive_iterator][:marking_method] = :invalid_method }

    it { expect(check).not_to be_success }
  end

  context 'when clean_after_yielding is not a boolean' do
    before { config[:adaptive_iterator][:clean_after_yielding] = nil }

    it { expect(check).not_to be_success }
  end

  context 'when trying to use the adaptive iterator with virtual partitions' do
    before { config[:virtual_partitions][:active] = true }

    it { expect(check).not_to be_success }
  end

  context 'when trying to use the adaptive iterator with long running job' do
    before { config[:long_running_job][:active] = true }

    it { expect(check).not_to be_success }
  end
end
