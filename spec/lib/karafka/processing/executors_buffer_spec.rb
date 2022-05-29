# frozen_string_literal: true

RSpec.describe_current do
  subject(:buffer) { described_class.new(client, subscription_group) }

  let(:client) { instance_double(Karafka::Connection::Client) }
  let(:group_id) { SecureRandom.uuid }
  let(:topic_name) { 'topic_name1' }
  let(:partition_id) { 0 }
  let(:pause) { nil }
  let(:fetched_executor) { buffer.fetch(topic_name, partition_id, pause) }
  let(:subscription_group) { consumer_groups.first.subscription_groups.first }
  let(:consumer_groups) do
    Karafka::Routing::Builder.new.draw do
      consumer_group :group_name1 do
        topic :topic_name1 do
          consumer Class.new(Karafka::BaseConsumer)
        end
      end
    end
  end

  describe '#fetch' do
    context 'when the executor is not in the buffer' do
      it { expect(fetched_executor.group_id).to eq(subscription_group.id) }

      it 'expect to create a new one' do
        expect(fetched_executor).to be_a(Karafka::Processing::Executor)
      end
    end

    context 'when executor is in a buffer' do
      let(:existing_executor) { buffer.fetch(topic_name, partition_id, pause) }

      before { existing_executor }

      it { expect(fetched_executor.group_id).to eq(subscription_group.id) }

      it 'expect to re-use existing one' do
        expect(fetched_executor).to eq(existing_executor)
      end
    end
  end

  describe '#each' do
    context 'when there are no executors' do
      it 'expect not to yield anything' do
        expect { |block| buffer.each(&block) }.not_to yield_control
      end
    end

    context 'when there are executors' do
      before { fetched_executor }

      it 'expect to yield with executor from this topic partition' do
        expect { |block| buffer.each(&block) }
          .to yield_with_args(consumer_groups.first.topics.first, partition_id, fetched_executor)
      end
    end
  end

  describe '#clear' do
    let(:pre_cleaned_executor) { buffer.fetch(topic_name, partition_id, pause) }

    before do
      pre_cleaned_executor
      buffer.clear
    end

    it 'expect to rebuild after clearing as clearing should empty the buffer' do
      expect(fetched_executor).not_to eq(pre_cleaned_executor)
    end
  end
end
