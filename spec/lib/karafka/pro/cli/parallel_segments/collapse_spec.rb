# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:command) { described_class.new(options) }

  let(:options) { {} }
  let(:segment_origin) { 'test-origin-group' }

  let(:parallel_routes) do
    [
      instance_double(
        Karafka::Routing::ConsumerGroup,
        name: 'test-origin-group-parallel-0',
        segment_origin: segment_origin,
        parallel_segments?: true,
        topics: [
          instance_double(Karafka::Routing::Topic, name: 'topic1'),
          instance_double(Karafka::Routing::Topic, name: 'topic2')
        ]
      ),
      instance_double(
        Karafka::Routing::ConsumerGroup,
        name: 'test-origin-group-parallel-1',
        segment_origin: segment_origin,
        parallel_segments?: true,
        topics: [
          instance_double(Karafka::Routing::Topic, name: 'topic1'),
          instance_double(Karafka::Routing::Topic, name: 'topic2')
        ]
      )
    ]
  end

  describe '#call' do
    before do
      allow(Karafka::App.routes).to receive(:select).and_return(parallel_routes)
      allow(Karafka::App.routes).to receive(:clear)

      allow(Karafka::Admin).to receive(:read_lags_with_offsets) do
        if use_misaligned_offsets
          {
            'test-origin-group' => {
              'topic1' => {
                '0' => { offset: 0, lag: 0 },
                '1' => { offset: 0, lag: 0 }
              },
              'topic2' => {
                '0' => { offset: 0, lag: 0 },
                '1' => { offset: 0, lag: 0 }
              }
            },
            'test-origin-group-parallel-0' => {
              'topic1' => {
                '0' => { offset: 100, lag: 0 },
                '1' => { offset: 200, lag: 0 }
              },
              'topic2' => {
                '0' => { offset: 100, lag: 0 },
                '1' => { offset: 200, lag: 0 }
              }
            },
            'test-origin-group-parallel-1' => {
              'topic1' => {
                '0' => { offset: 90, lag: 0 },
                '1' => { offset: 210, lag: 0 }
              },
              'topic2' => {
                '0' => { offset: 110, lag: 0 },
                '1' => { offset: 190, lag: 0 }
              }
            }
          }
        else
          {
            'test-origin-group' => {
              'topic1' => {
                '0' => { offset: 0, lag: 0 },
                '1' => { offset: 0, lag: 0 }
              },
              'topic2' => {
                '0' => { offset: 0, lag: 0 },
                '1' => { offset: 0, lag: 0 }
              }
            },
            'test-origin-group-parallel-0' => {
              'topic1' => {
                '0' => { offset: 100, lag: 0 },
                '1' => { offset: 200, lag: 0 }
              },
              'topic2' => {
                '0' => { offset: 100, lag: 0 },
                '1' => { offset: 200, lag: 0 }
              }
            },
            'test-origin-group-parallel-1' => {
              'topic1' => {
                '0' => { offset: 100, lag: 0 },
                '1' => { offset: 200, lag: 0 }
              },
              'topic2' => {
                '0' => { offset: 100, lag: 0 },
                '1' => { offset: 200, lag: 0 }
              }
            }
          }
        end
      end

      allow(Karafka::Admin).to receive(:seek_consumer_group)
    end

    let(:use_misaligned_offsets) { false }

    context 'when applicable groups exist with aligned offsets' do
      it 'collapses offsets to the segment origin consumer group' do
        command.call

        expect(Karafka::Admin)
          .to have_received(:seek_consumer_group)
          .with(
            segment_origin,
            hash_including(
              'topic1' => { '0' => 100, '1' => 200 },
              'topic2' => { '0' => 100, '1' => 200 }
            )
          )
      end
    end

    context 'when no applicable groups are found' do
      before do
        allow(Karafka::App.routes).to receive(:select).and_return([])
        allow(Karafka::App.routes).to receive(:clear)
      end

      it 'completes without seeking any consumer groups' do
        command.call
        expect(Karafka::Admin).not_to have_received(:seek_consumer_group)
      end
    end

    context 'when segments have misaligned offsets' do
      let(:use_misaligned_offsets) { true }

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
                'topic2' => { '0' => 100, '1' => 190 }
              )
            )
        end
      end
    end
  end

  describe 'integration with Admin API' do
    before do
      allow(Karafka::App.routes).to receive(:select).and_return(parallel_routes)
      allow(Karafka::App.routes).to receive(:clear)

      allow(Karafka::Admin).to receive(:read_lags_with_offsets).and_return(
        {
          'test-origin-group' => {
            'topic1' => {
              '0' => { offset: 0, lag: 0 },
              '1' => { offset: 0, lag: 0 }
            },
            'topic2' => {
              '0' => { offset: 0, lag: 0 },
              '1' => { offset: 0, lag: 0 }
            }
          },
          'test-origin-group-parallel-0' => {
            'topic1' => {
              '0' => { offset: 100, lag: 0 },
              '1' => { offset: 200, lag: 0 }
            },
            'topic2' => {
              '0' => { offset: 100, lag: 0 },
              '1' => { offset: 200, lag: 0 }
            }
          },
          'test-origin-group-parallel-1' => {
            'topic1' => {
              '0' => { offset: 100, lag: 0 },
              '1' => { offset: 200, lag: 0 }
            },
            'topic2' => {
              '0' => { offset: 100, lag: 0 },
              '1' => { offset: 200, lag: 0 }
            }
          }
        }
      )

      allow(Karafka::Admin).to receive(:seek_consumer_group)
    end

    it 'uses Admin API to seek consumer group with appropriate offsets' do
      command.call

      expect(Karafka::Admin).to have_received(:seek_consumer_group).with(
        segment_origin,
        hash_including(
          'topic1' => { '0' => 100, '1' => 200 },
          'topic2' => { '0' => 100, '1' => 200 }
        )
      )
    end
  end
end
