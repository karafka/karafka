# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:builder) { builder_class.new }

  let(:builder_class) do
    Class.new(Karafka::Routing::Builder) do
      prepend Karafka::Pro::Routing::Features::ParallelSegments::Builder
    end
  end

  let(:parallel_segments_config) do
    Karafka::Pro::Routing::Features::ParallelSegments::Config.new(
      active: parallel_active,
      count: segments_count,
      merge_key: '-parallel-',
      partitioner: nil,
      reducer: ->(key) { key }
    )
  end

  let(:parallel_active) { false }
  let(:segments_count) { 1 }

  describe '#consumer_group' do
    context 'when reopening an existing consumer group' do
      let(:consumer_group) { instance_double(Karafka::Routing::ConsumerGroup, name: 'test-group') }
      let(:proxy) { instance_double(Karafka::Routing::Proxy, target: consumer_group) }
      let(:consumer_group_class_spy) { class_spy(Karafka::Routing::ConsumerGroup) }

      before do
        allow(builder).to receive(:find).and_return(consumer_group)
        allow(Karafka::Routing::Proxy).to receive(:new).and_return(proxy)
      end

      it 'uses the existing consumer group' do
        stub_const('Karafka::Routing::ConsumerGroup', consumer_group_class_spy)
        builder.consumer_group('test-group') {}
        expect(consumer_group_class_spy).not_to have_received(:new)
      end
    end

    context 'when creating a new consumer group' do
      let(:proxy_block) { proc {} }

      before do
        allow(builder).to receive(:find).and_return(nil)
        allow(builder).to receive(:<<)
      end

      context 'with parallel segments disabled' do
        let(:parallel_active) { false }
        let(:temp_consumer_group) do
          instance_double(Karafka::Routing::ConsumerGroup, name: 'test-group')
        end

        let(:temp_target) do
          instance_double(
            Karafka::Routing::ConsumerGroup,
            parallel_segments: parallel_segments_config
          )
        end

        let(:temp_proxy) do
          instance_double(Karafka::Routing::Proxy, target: temp_target)
        end

        before do
          allow(Karafka::Routing::ConsumerGroup).to receive(:new).and_return(temp_consumer_group)
          allow(Karafka::Routing::Proxy).to receive(:new).and_return(temp_proxy)
        end

        it 'creates a single consumer group' do
          allow(builder).to receive(:<<)
          builder.consumer_group('test-group', &proxy_block)
          expect(builder).to have_received(:<<).once
        end
      end

      context 'with parallel segments enabled' do
        let(:parallel_active) { true }
        let(:segments_count) { 3 }

        let(:temp_consumer_group) do
          instance_double(Karafka::Routing::ConsumerGroup, name: 'test-group')
        end

        let(:temp_target) do
          instance_double(
            Karafka::Routing::ConsumerGroup,
            parallel_segments: parallel_segments_config
          )
        end

        let(:temp_proxy) do
          instance_double(Karafka::Routing::Proxy, target: temp_target)
        end

        before do
          allow(Karafka::Routing::ConsumerGroup)
            .to receive(:new)
            .and_return(temp_consumer_group)

          allow(Karafka::Routing::Proxy)
            .to receive(:new)
            .with(temp_consumer_group, &proxy_block)
            .and_return(temp_proxy)

          segments_count.times do |i|
            group_name = "test-group-parallel-#{i}"
            segment_group = instance_double(Karafka::Routing::ConsumerGroup, name: group_name)
            segment_proxy = instance_double(Karafka::Routing::Proxy, target: segment_group)

            allow(Karafka::Routing::ConsumerGroup)
              .to receive(:new)
              .with(group_name)
              .and_return(segment_group)

            allow(Karafka::Routing::Proxy)
              .to receive(:new)
              .with(segment_group, &proxy_block)
              .and_return(segment_proxy)
          end
        end

        it 'creates multiple consumer groups based on the count' do
          allow(builder).to receive(:<<)
          builder.consumer_group('test-group', &proxy_block)
          expect(builder).to have_received(:<<).exactly(segments_count).times
        end

        it 'uses the merge key in the group names' do
          consumer_group_class_spy = class_spy(Karafka::Routing::ConsumerGroup)
          stub_const('Karafka::Routing::ConsumerGroup', consumer_group_class_spy)

          # Create the necessary doubles for the test
          temp_consumer_group = instance_double(
            Karafka::Routing::ConsumerGroup,
            name: 'test-group'
          )
          temp_target = instance_double(
            Karafka::Routing::ConsumerGroup,
            parallel_segments: parallel_segments_config
          )
          temp_proxy = instance_double(Karafka::Routing::Proxy, target: temp_target)

          # Set up the initial stub for creating the temp group
          allow(consumer_group_class_spy).to receive(:new).and_return(temp_consumer_group)

          # Set up the proxy stub
          allow(Karafka::Routing::Proxy).to receive(:new)
            .with(temp_consumer_group, &proxy_block)
            .and_return(temp_proxy)

          # Set up stubs for the parallel segment groups
          segments_count.times do |i|
            group_name = "test-group-parallel-#{i}"
            segment_group = instance_double(Karafka::Routing::ConsumerGroup, name: group_name)
            segment_proxy = instance_double(Karafka::Routing::Proxy, target: segment_group)

            allow(consumer_group_class_spy)
              .to receive(:new)
              .with(group_name)
              .and_return(segment_group)

            allow(Karafka::Routing::Proxy)
              .to receive(:new)
              .with(segment_group, &proxy_block)
              .and_return(segment_proxy)
          end

          # Execute the action
          builder.consumer_group('test-group', &proxy_block)

          # Verify expectations
          expect(consumer_group_class_spy).to have_received(:new).with('test-group-parallel-0')
          expect(consumer_group_class_spy).to have_received(:new).with('test-group-parallel-1')
          expect(consumer_group_class_spy).to have_received(:new).with('test-group-parallel-2')
        end
      end
    end
  end
end
