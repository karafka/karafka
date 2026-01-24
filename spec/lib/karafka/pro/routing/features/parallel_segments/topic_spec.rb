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
  let(:consumer_group) { build(:routing_consumer_group) }

  let(:base_topic_class) do
    Class.new(build(:routing_topic).class) do
      attr_writer :manual_offset_management

      attr_reader :builder

      def manual_offset_management?
        @manual_offset_management
      end

      # Override filter to avoid double calls and track the builder
      alias_method :original_filter, :filter

      def filter(builder)
        @builder = builder
        original_filter(builder)
      end
    end
  end

  let(:topic_class) do
    Class.new(base_topic_class) do
      prepend Karafka::Pro::Routing::Features::ParallelSegments::Topic
    end
  end

  let(:parallel_segments_enabled) { true }
  let(:parallel_segments_config) do
    Karafka::Pro::Routing::Features::ParallelSegments::Config.new(
      active: true,
      count: 3,
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
      # We use a spy for the topic so we can check if filter is called
      topic_spy = instance_spy(base_topic_class)
      allow(topic_class).to receive(:new).and_return(topic_spy)
      allow(topic_spy).to receive(:manual_offset_management?).and_return(mom_enabled)

      # Create new topic
      topic_class.new('test', consumer_group)

      # Verify filter wasn't called
      expect(topic_spy).not_to have_received(:filter)
    end
  end

  context 'when parallel segments are enabled' do
    let(:parallel_segments_enabled) { true }

    context 'when manual offset management is enabled' do
      let(:mom_enabled) { true }

      it 'adds MoM filter' do
        # Create and configure the topic
        topic = topic_class.new('test', consumer_group)
        topic.manual_offset_management = mom_enabled

        # Get the builder and call it to create the filter
        builder = topic.builder
        filter = builder.call(topic, 0)

        # Verify filter type
        expect(filter).to be_instance_of(
          Karafka::Pro::Processing::ParallelSegments::Filters::Mom
        )
      end

      it 'configures filter with correct group_id' do
        # Create and configure the topic
        topic = topic_class.new('test', consumer_group)
        topic.manual_offset_management = mom_enabled

        # Get the builder and call it to create the filter
        builder = topic.builder
        filter = builder.call(topic, 0)

        # Verify group_id
        expect(filter.instance_variable_get(:@segment_id)).to eq(1)
      end

      it 'configures filter with partitioner from config' do
        # Create and configure the topic
        topic = topic_class.new('test', consumer_group)
        topic.manual_offset_management = mom_enabled

        # Get the builder and call it to create the filter
        builder = topic.builder
        filter = builder.call(topic, 0)

        # Verify partitioner
        expect(filter.instance_variable_get(:@partitioner))
          .to eq(parallel_segments_config.partitioner)
      end

      it 'configures filter with reducer from config' do
        # Create and configure the topic
        topic = topic_class.new('test', consumer_group)
        topic.manual_offset_management = mom_enabled

        # Get the builder and call it to create the filter
        builder = topic.builder
        filter = builder.call(topic, 0)

        # Verify reducer
        expect(filter.instance_variable_get(:@reducer))
          .to eq(parallel_segments_config.reducer)
      end
    end

    context 'when manual offset management is disabled' do
      let(:mom_enabled) { false }

      it 'adds Default filter' do
        # Create and configure the topic
        topic = topic_class.new('test', consumer_group)
        topic.manual_offset_management = mom_enabled

        # Get the builder and call it to create the filter
        builder = topic.builder
        filter = builder.call(topic, 0)

        # Verify filter type
        expect(filter).to be_instance_of(
          Karafka::Pro::Processing::ParallelSegments::Filters::Default
        )
      end

      it 'configures filter with correct group_id' do
        # Create and configure the topic
        topic = topic_class.new('test', consumer_group)
        topic.manual_offset_management = mom_enabled

        # Get the builder and call it to create the filter
        builder = topic.builder
        filter = builder.call(topic, 0)

        # Verify group_id
        expect(filter.instance_variable_get(:@segment_id)).to eq(1)
      end
    end
  end
end
