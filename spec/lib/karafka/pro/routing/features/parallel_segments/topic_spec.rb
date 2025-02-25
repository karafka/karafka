# frozen_string_literal: true
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  let(:consumer_group) { build(:routing_consumer_group) }
  let(:topic_class) do
    Class.new(build(:routing_topic).class) do
      prepend Karafka::Pro::Routing::Features::ParallelSegments::Topic
    end
  end

  let(:parallel_segments_enabled) { true }
  let(:parallel_segments_config) do
    instance_double(
      'Karafka::Pro::Routing::Features::ParallelSegments::Config',
      merge_key: '-parallel-',
      partitioner: -> { 1 },
      reducer: -> { 1 }
    )
  end
  let(:consumer_group_name) { 'group-name-parallel-1' }
  let(:mom_enabled) { false }

  before do
    allow(consumer_group).to receive_messages(
      parallel_segments?: parallel_segments_enabled,
      parallel_segments: parallel_segments_config,
      name: consumer_group_name
    )
  end

  context 'when parallel segments are disabled' do
    let(:parallel_segments_enabled) { false }
    let(:mom_enabled) { false }

    it 'does not add any filters' do
      topic = topic_class.new('test', consumer_group)
      expect(topic).not_to have_received(:filter)
    end
  end

  context 'when parallel segments are enabled' do
    let(:parallel_segments_enabled) { true }

    context 'when manual offset management is enabled' do
      let(:mom_enabled) { true }

      let(:topic) do
        instance = topic_class.allocate
        allow(instance).to receive(:filter)
        allow(instance).to receive(:manual_offset_management?).and_return(mom_enabled)
        instance.send(:initialize, 'test', consumer_group)
        instance
      end

      it 'adds MoM filter' do
        expect(topic).to have_received(:filter) do |builder|
          filter = builder.call(topic, 0)
          expect(filter).to be_instance_of(
            Karafka::Pro::Processing::ParallelSegments::Filters::Mom
          )
        end
      end

      it 'configures filter with correct group_id' do
        expect(topic).to have_received(:filter) do |builder|
          filter = builder.call(topic, 0)
          expect(filter.instance_variable_get(:@group_id)).to eq(1)
        end
      end

      it 'configures filter with partitioner from config' do
        expect(topic).to have_received(:filter) do |builder|
          filter = builder.call(topic, 0)
          expect(filter.instance_variable_get(:@partitioner))
            .to eq(parallel_segments_config.partitioner)
        end
      end

      it 'configures filter with reducer from config' do
        expect(topic).to have_received(:filter) do |builder|
          filter = builder.call(topic, 0)
          expect(filter.instance_variable_get(:@reducer))
            .to eq(parallel_segments_config.reducer)
        end
      end
    end

    context 'when manual offset management is disabled' do
      let(:mom_enabled) { false }

      let(:topic) do
        instance = topic_class.allocate
        allow(instance).to receive(:filter)
        allow(instance).to receive(:manual_offset_management?).and_return(mom_enabled)
        instance.send(:initialize, 'test', consumer_group)
        instance
      end

      it 'adds Default filter' do
        expect(topic).to have_received(:filter) do |builder|
          filter = builder.call(topic, 0)
          expect(filter).to be_instance_of(
            Karafka::Pro::Processing::ParallelSegments::Filters::Default
          )
        end
      end

      it 'configures filter with correct group_id' do
        expect(topic).to have_received(:filter) do |builder|
          filter = builder.call(topic, 0)
          expect(filter.instance_variable_get(:@group_id)).to eq(1)
        end
      end
    end
  end
end
