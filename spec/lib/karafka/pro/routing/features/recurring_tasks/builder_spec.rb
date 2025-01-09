# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:builder) do
    Karafka::Routing::Builder.new.tap do |builder|
      builder.singleton_class.prepend described_class
    end
  end

  let(:topic) { builder.first.topics.first }

  describe '#recurring_tasks' do
    context 'when defining recurring tasks without any extra settings' do
      before { builder.recurring_tasks(true) }

      it { expect(topic.consumer).to eq(Karafka::Pro::RecurringTasks::Consumer) }
      it { expect(topic.recurring_tasks?).to be(true) }
    end

    context 'when defining recurring tasks with extra settings' do
      before do
        builder.recurring_tasks(true) do
          max_messages 5
        end
      end

      it { expect(topic.consumer).to eq(Karafka::Pro::RecurringTasks::Consumer) }
      it { expect(topic.recurring_tasks?).to be(true) }
      it { expect(topic.max_messages).to eq(5) }
    end
  end
end
