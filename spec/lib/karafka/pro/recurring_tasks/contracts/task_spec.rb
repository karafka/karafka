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
  subject(:contract) { described_class.new }

  let(:task) do
    {
      id: 'task_1',
      cron: '* * * * *',
      enabled: true,
      changed: false,
      previous_time: 1_679_334_800
    }
  end

  context 'when task is valid' do
    it { expect(contract.call(task)).to be_success }
  end

  context 'when id does not match the required format' do
    before { task[:id] = 'invalid id!' }

    it { expect(contract.call(task)).not_to be_success }
  end

  context 'when id is not a string' do
    before { task[:id] = 12_345 }

    it { expect(contract.call(task)).not_to be_success }
  end

  context 'when cron is an empty string' do
    before { task[:cron] = '' }

    it { expect(contract.call(task)).not_to be_success }
  end

  context 'when cron is not a string' do
    before { task[:cron] = 12_345 }

    it { expect(contract.call(task)).not_to be_success }
  end

  context 'when enabled is nil' do
    before { task[:enabled] = nil }

    it { expect(contract.call(task)).not_to be_success }
  end

  context 'when enabled is not a boolean' do
    before { task[:enabled] = 'true' }

    it { expect(contract.call(task)).not_to be_success }
  end

  context 'when changed is nil' do
    before { task[:changed] = nil }

    it { expect(contract.call(task)).not_to be_success }
  end

  context 'when changed is not a boolean' do
    before { task[:changed] = 'false' }

    it { expect(contract.call(task)).not_to be_success }
  end

  context 'when previous_time is not numeric' do
    before { task[:previous_time] = 'not numeric' }

    it { expect(contract.call(task)).not_to be_success }
  end
end
