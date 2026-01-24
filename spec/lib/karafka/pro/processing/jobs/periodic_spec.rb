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
  subject(:job) { described_class.new(executor) }

  let(:executor) { build(:processing_executor) }

  before do
    allow(executor).to receive(:periodic)
    job.call
  end

  specify { expect(described_class.action).to eq(:tick) }

  it { expect(job.id).to eq(executor.id) }
  it { expect(job.group_id).to eq(executor.group_id) }
  it { expect(job.non_blocking?).to be(false) }

  it 'expect to run periodic on the executor' do
    expect(executor).to have_received(:periodic)
  end

  describe '#before_schedule' do
    before do
      allow(executor).to receive(:before_schedule_periodic)
      job.before_schedule
    end

    it 'expect to run before_schedule_periodic on the executor' do
      expect(executor).to have_received(:before_schedule_periodic)
    end
  end
end
