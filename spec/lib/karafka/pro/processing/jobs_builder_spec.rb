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
  subject(:builder) { described_class.new }

  let(:executor) { build(:processing_executor) }
  let(:coordinator) { executor.coordinator }
  let(:topic) { coordinator.topic }

  describe '#consume' do
    context 'when it is a lrj topic' do
      before { coordinator.topic.long_running_job true }

      it 'expect to use the non blocking pro consumption job' do
        job = builder.consume(executor, [])
        expect(job).to be_a(Karafka::Pro::Processing::Jobs::ConsumeNonBlocking)
      end
    end

    context 'when it is not a lrj topic' do
      it do
        job = builder.consume(executor, [])
        expect(job).to be_a(Karafka::Processing::Jobs::Consume)
      end
    end
  end

  describe '#eofed' do
    context 'when it is a lrj topic' do
      before { coordinator.topic.long_running_job true }

      it 'expect to use the non blocking pro revocation job' do
        job = builder.eofed(executor)
        expect(job).to be_a(Karafka::Pro::Processing::Jobs::EofedNonBlocking)
      end
    end

    context 'when it is not a lrj topic' do
      it do
        job = builder.eofed(executor)
        expect(job).to be_a(Karafka::Processing::Jobs::Eofed)
      end
    end
  end

  describe '#revoked' do
    context 'when it is a lrj topic' do
      before { coordinator.topic.long_running_job true }

      it 'expect to use the non blocking pro revocation job' do
        job = builder.revoked(executor)
        expect(job).to be_a(Karafka::Pro::Processing::Jobs::RevokedNonBlocking)
      end
    end

    context 'when it is not a lrj topic' do
      it do
        job = builder.revoked(executor)
        expect(job).to be_a(Karafka::Processing::Jobs::Revoked)
      end
    end
  end

  describe '#shutdown' do
    it do
      job = builder.shutdown(executor)
      expect(job).to be_a(Karafka::Processing::Jobs::Shutdown)
    end
  end

  describe '#idle' do
    it do
      job = builder.idle(executor)
      expect(job).to be_a(Karafka::Processing::Jobs::Idle)
    end
  end

  describe '#periodic' do
    context 'when it is a lrj topic' do
      before { coordinator.topic.long_running_job true }

      it 'expect to use the non blocking pro revocation job' do
        job = builder.periodic(executor)
        expect(job).to be_a(Karafka::Pro::Processing::Jobs::PeriodicNonBlocking)
      end
    end

    context 'when it is not a lrj topic' do
      it do
        job = builder.periodic(executor)
        expect(job).to be_a(Karafka::Pro::Processing::Jobs::Periodic)
      end
    end
  end
end
