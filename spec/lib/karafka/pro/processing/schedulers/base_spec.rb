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
  subject(:scheduler) { described_class.new(queue) }

  let(:queue) { [] }
  let(:jobs_array) { [] }

  describe '#on_schedule_consumption' do
    it { expect { scheduler.on_schedule_consumption([]) }.to raise_error(NotImplementedError) }
  end

  describe '#schedule_consumption' do
    it { expect { scheduler.schedule_consumption([]) }.to raise_error(NotImplementedError) }
  end

  %i[
    on_schedule_revocation
    on_schedule_shutdown
    on_schedule_idle
    on_schedule_periodic
  ].each do |action|
    describe "##{action}" do
      subject(:schedule) { scheduler.public_send(action, jobs_array) }

      context 'when there are no messages' do
        it 'expect not to schedule anything' do
          schedule
          expect(queue).to be_empty
        end
      end

      context 'when there are jobs' do
        let(:jobs_array) do
          [
            Karafka::Processing::Jobs::Consume.new(nil, []),
            Karafka::Processing::Jobs::Consume.new(nil, []),
            Karafka::Processing::Jobs::Consume.new(nil, []),
            Karafka::Processing::Jobs::Consume.new(nil, [])
          ]
        end

        it 'expect to schedule in the fifo order' do
          schedule
          expect(queue).to eq(jobs_array)
        end
      end
    end
  end

  describe '#on_manage' do
    it { expect { scheduler.on_manage }.not_to raise_error }
  end

  describe '#manage' do
    it { expect { scheduler.manage }.not_to raise_error }
  end

  describe '#on_clear' do
    it { expect { scheduler.on_clear(1) }.not_to raise_error }
  end

  describe '#clear' do
    it { expect { scheduler.clear(1) }.not_to raise_error }
  end
end
