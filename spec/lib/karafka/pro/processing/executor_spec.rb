# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:executor) { described_class.new(group_id, client, coordinator) }

  let(:group_id) { rand.to_s }
  let(:client) { instance_double(Karafka::Connection::Client) }
  let(:coordinator) { build(:processing_coordinator) }
  let(:topic) { coordinator.topic }
  let(:messages) { [build(:messages_message)] }
  let(:coordinator) { build(:processing_coordinator) }
  let(:consumer) do
    ClassBuilder.inherit(topic.consumer) do
      def consume; end
    end.new
  end

  before { allow(topic.consumer).to receive(:new).and_return(consumer) }

  describe '#before_schedule_periodic' do
    before { allow(consumer).to receive(:on_before_schedule_tick) }

    it do
      expect { executor.before_schedule_periodic }.not_to raise_error
    end

    it 'expect to run consumer on_before_schedule' do
      executor.before_schedule_periodic
      expect(consumer).to have_received(:on_before_schedule_tick).with(no_args)
    end
  end

  describe '#periodic' do
    before do
      allow(consumer).to receive(:on_tick)
      executor.periodic
    end

    it 'expect to run consumer on_tick' do
      expect(consumer).to have_received(:on_tick).with(no_args)
    end
  end
end
