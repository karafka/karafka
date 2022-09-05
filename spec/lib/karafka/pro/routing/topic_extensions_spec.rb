# frozen_string_literal: true

require 'karafka/pro/routing/topic_extensions'

RSpec.describe_current do
  subject(:extended_topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend Karafka::Pro::Routing::TopicExtensions
    end
  end

  it 'expect not to use lrj by default' do
    expect(extended_topic.long_running_job?).to eq(false)
  end

  context 'when lrj is set' do
    before { extended_topic.long_running_job = true }

    it { expect(extended_topic.long_running_job?).to eq(true) }
  end

  it 'expect not to use virtual partitioner by default' do
    expect(extended_topic.virtual_partitions?).to eq(false)
  end

  context 'when virtual partitioner is set' do
    before do
      extended_topic.virtual_partitions(
        partitioner: ->(msg) { msg.raw_payload }
      )
    end

    it { expect(extended_topic.virtual_partitions?).to eq(true) }
  end
end
