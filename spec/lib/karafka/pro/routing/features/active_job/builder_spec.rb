# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:builder) do
    Karafka::Routing::Builder.new.tap do |builder|
      builder.singleton_class.prepend described_class
    end
  end

  let(:topic) { builder.first.topics.first }

  describe '#active_job_pattern' do
    context 'when defining AJ pattern without any extra settings' do
      before { builder.active_job_pattern(/test/) }

      it { expect(topic.consumer).to eq(Karafka::Pro::ActiveJob::Consumer) }
      it { expect(topic.active_job?).to be(true) }
      it { expect(topic.patterns.active?).to be(true) }
      it { expect(topic.patterns.matcher?).to be(true) }
    end

    context 'when defining AJ pattern with extra settings' do
      before do
        builder.active_job_pattern(/test/) do
          max_messages 5
        end
      end

      it { expect(topic.consumer).to eq(Karafka::Pro::ActiveJob::Consumer) }
      it { expect(topic.active_job?).to be(true) }
      it { expect(topic.max_messages).to eq(5) }
      it { expect(topic.patterns.active?).to be(true) }
      it { expect(topic.patterns.matcher?).to be(true) }
    end
  end
end
