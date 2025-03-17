# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:command) { described_class.new(options) }

  let(:options) { {} }
  let(:segment_origin) { 'test-origin-group' }
  let(:segments) { [segment1, segment2] }
  let(:applicable_groups) { { segment_origin => segments } }

  let(:segment1) do
    instance_double(Karafka::Routing::ConsumerGroup, name: 'test-origin-group-parallel-0')
  end

  let(:segment2) do
    instance_double(Karafka::Routing::ConsumerGroup, name: 'test-origin-group-parallel-1')
  end

  # Setup test data for different scenarios
  let(:origin_with_offsets) do
    {
      'test-origin-group' => {
        'topic1' => { '0' => 100, '1' => 200 },
        'topic2' => { '0' => 300, '1' => 400 }
      },
      'test-origin-group-parallel-0' => {
        'topic1' => { '0' => 0, '1' => 0 },
        'topic2' => { '0' => 0, '1' => 0 }
      },
      'test-origin-group-parallel-1' => {
        'topic1' => { '0' => 0, '1' => 0 },
        'topic2' => { '0' => 0, '1' => 0 }
      }
    }
  end

  let(:segments_with_offsets) do
    {
      'test-origin-group' => {
        'topic1' => { '0' => 100, '1' => 200 },
        'topic2' => { '0' => 300, '1' => 400 }
      },
      'test-origin-group-parallel-0' => {
        'topic1' => { '0' => 50, '1' => 150 },
        'topic2' => { '0' => 250, '1' => 350 }
      },
      'test-origin-group-parallel-1' => {
        'topic1' => { '0' => 0, '1' => 0 },
        'topic2' => { '0' => 0, '1' => 0 }
      }
    }
  end

  describe '#call' do
    before do
      allow(command).to receive_messages(
        applicable_groups: applicable_groups,
        collect_offsets: origin_with_offsets
      )

      allow(Karafka::Admin)
        .to receive(:seek_consumer_group)
    end

    context 'when applicable groups exist with offsets to distribute' do
      it 'distributes offsets to all segment consumer groups' do
        command.call

        expect(Karafka::Admin)
          .to have_received(:seek_consumer_group)
          .with(
            'test-origin-group-parallel-0',
            hash_including(
              'topic1' => { '0' => 100, '1' => 200 },
              'topic2' => { '0' => 300, '1' => 400 }
            )
          )

        expect(Karafka::Admin)
          .to have_received(:seek_consumer_group)
          .with(
            'test-origin-group-parallel-1',
            hash_including(
              'topic1' => { '0' => 100, '1' => 200 },
              'topic2' => { '0' => 300, '1' => 400 }
            )
          )
      end
    end

    context 'when no applicable groups are found' do
      let(:applicable_groups) { {} }

      it 'completes without seeking any consumer groups' do
        command.call
        expect(Karafka::Admin).not_to have_received(:seek_consumer_group)
      end
    end

    context 'when a segment already has offsets' do
      before do
        allow(command)
          .to receive(:collect_offsets)
          .and_return(segments_with_offsets)
      end

      context 'without force option' do
        it 'raises CommandValidationError' do
          expect { command.call }.to raise_error(Karafka::Errors::CommandValidationError)
        end
      end

      context 'with force option' do
        let(:options) { { force: true } }

        it 'distributes offsets despite existing segment offsets' do
          command.call
          expect(Karafka::Admin)
            .to have_received(:seek_consumer_group)
            .twice
        end
      end
    end
  end
end
