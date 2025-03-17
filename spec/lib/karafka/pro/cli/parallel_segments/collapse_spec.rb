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
    instance_double(
      Karafka::Routing::ConsumerGroup,
      name: 'test-origin-group-parallel-0',
      segment_origin: segment_origin
    )
  end

  let(:segment2) do
    instance_double(
      Karafka::Routing::ConsumerGroup,
      name: 'test-origin-group-parallel-1',
      segment_origin: segment_origin
    )
  end

  # Setup test data for different scenarios
  let(:aligned_offsets) do
    {
      'test-origin-group' => {
        'topic1' => { '0' => 0, '1' => 0 },
        'topic2' => { '0' => 0, '1' => 0 }
      },
      'test-origin-group-parallel-0' => {
        'topic1' => { '0' => 100, '1' => 200 },
        'topic2' => { '0' => 300, '1' => 400 }
      },
      'test-origin-group-parallel-1' => {
        'topic1' => { '0' => 100, '1' => 200 },
        'topic2' => { '0' => 300, '1' => 400 }
      }
    }
  end

  let(:misaligned_offsets) do
    {
      'test-origin-group' => {
        'topic1' => { '0' => 0, '1' => 0 },
        'topic2' => { '0' => 0, '1' => 0 }
      },
      'test-origin-group-parallel-0' => {
        'topic1' => { '0' => 100, '1' => 200 },
        'topic2' => { '0' => 300, '1' => 400 }
      },
      'test-origin-group-parallel-1' => {
        'topic1' => { '0' => 90, '1' => 210 },
        'topic2' => { '0' => 310, '1' => 390 }
      }
    }
  end

  describe '#call' do
    before do
      allow(command).to receive_messages(
        applicable_groups: applicable_groups,
        collect_offsets: aligned_offsets
      )

      allow(Karafka::Admin)
        .to receive(:seek_consumer_group)
    end

    context 'when applicable groups exist with aligned offsets' do
      it 'collapses offsets to the segment origin consumer group' do
        command.call

        expect(Karafka::Admin)
          .to have_received(:seek_consumer_group)
          .with(
            segment_origin,
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

    context 'when segments have misaligned offsets' do
      before do
        allow(command)
          .to receive(:collect_offsets)
          .and_return(misaligned_offsets)
      end

      context 'without force option' do
        it 'raises CommandValidationError' do
          expect { command.call }.to raise_error(Karafka::Errors::CommandValidationError)
        end
      end

      context 'with force option' do
        let(:options) { { force: true } }

        it 'collapses to the lowest offsets for each partition' do
          command.call

          expect(Karafka::Admin)
            .to have_received(:seek_consumer_group)
            .with(
              segment_origin,
              hash_including(
                'topic1' => { '0' => 90, '1' => 200 },
                'topic2' => { '0' => 300, '1' => 390 }
              )
            )
        end
      end
    end
  end

  describe 'collapse logic' do
    it 'selects the lowest offsets from segments for each partition' do
      allow(command).to receive_messages(
        applicable_groups: applicable_groups,
        collect_offsets: misaligned_offsets
      )

      allow(Karafka::Admin).to receive(:seek_consumer_group)

      command.send(:options)[:force] = true
      command.call

      expect(Karafka::Admin)
        .to have_received(:seek_consumer_group)
        .with(
          segment_origin,
          hash_including(
            'topic1' => { '0' => 90, '1' => 200 },
            'topic2' => { '0' => 300, '1' => 390 }
          )
        )
    end
  end

  describe 'validation logic' do
    context 'when offsets are aligned' do
      it 'passes validation' do
        expect do
          command.send(:validate!, aligned_offsets, segment_origin)
        end.not_to raise_error
      end
    end

    context 'when offsets are misaligned' do
      it 'fails validation with appropriate error' do
        expect do
          command.send(:validate!, misaligned_offsets, segment_origin)
        end.to raise_error(
          Karafka::Errors::CommandValidationError
        )
      end
    end
  end
end
