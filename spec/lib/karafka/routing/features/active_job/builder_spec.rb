# frozen_string_literal: true

RSpec.describe_current do
  subject(:builder) do
    Karafka::Routing::Builder.new.tap do |builder|
      builder.singleton_class.prepend described_class
    end
  end

  let(:topic) { builder.first.topics.first }

  describe '#active_job_topic' do
    context 'when defining AJ without any extra settings' do
      before { builder.active_job_topic(:test) }

      it { expect(topic.consumer).to eq(Karafka::ActiveJob::Consumer) }
      it { expect(topic.active_job?).to eq(true) }
    end

    context 'when defining AJ with extra settings' do
      before do
        builder.active_job_topic(:test) do
          max_messages 5
        end
      end

      it { expect(topic.consumer).to eq(Karafka::ActiveJob::Consumer) }
      it { expect(topic.active_job?).to eq(true) }
      it { expect(topic.max_messages).to eq(5) }
    end
  end
end
