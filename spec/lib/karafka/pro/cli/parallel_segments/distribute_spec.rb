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
  subject(:command) { described_class.new(options) }

  let(:options) { {} }

  describe '#call' do
    before do
      allow(Karafka::App.routes).to receive(:select).and_return(parallel_routes)
      allow(Karafka::App.routes).to receive(:clear)

      allow(Karafka::Admin).to receive(:read_lags_with_offsets).and_return(offsets_data)
      allow(Karafka::Admin).to receive(:seek_consumer_group)
    end

    let(:parallel_routes) do
      segment_origin = 'test-origin-group'

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

    let(:offsets_data) do
      {
        'test-origin-group' => {
          'topic1' => {
            '0' => { offset: 100, lag: 0 },
            '1' => { offset: 200, lag: 0 }
          },
          'topic2' => {
            '0' => { offset: 300, lag: 0 },
            '1' => { offset: 400, lag: 0 }
          }
        },
        'test-origin-group-parallel-0' => {
          'topic1' => {
            '0' => { offset: 0, lag: 0 },
            '1' => { offset: 0, lag: 0 }
          },
          'topic2' => {
            '0' => { offset: 0, lag: 0 },
            '1' => { offset: 0, lag: 0 }
          }
        },
        'test-origin-group-parallel-1' => {
          'topic1' => {
            '0' => { offset: 0, lag: 0 },
            '1' => { offset: 0, lag: 0 }
          },
          'topic2' => {
            '0' => { offset: 0, lag: 0 },
            '1' => { offset: 0, lag: 0 }
          }
        }
      }
    end

    it 'distributes offsets to all segment consumer groups' do
      command.call

      expect(Karafka::Admin).to have_received(:seek_consumer_group)
        .with(
          'test-origin-group-parallel-0',
          hash_including(
            'topic1' => hash_including('0' => 100, '1' => 200),
            'topic2' => hash_including('0' => 300, '1' => 400)
          )
        )

      expect(Karafka::Admin).to have_received(:seek_consumer_group)
        .with(
          'test-origin-group-parallel-1',
          hash_including(
            'topic1' => hash_including('0' => 100, '1' => 200),
            'topic2' => hash_including('0' => 300, '1' => 400)
          )
        )
    end

    context 'when segments already have offsets' do
      let(:offsets_data) do
        {
          'test-origin-group' => {
            'topic1' => {
              '0' => { offset: 100, lag: 0 },
              '1' => { offset: 200, lag: 0 }
            }
          },
          'test-origin-group-parallel-0' => {
            'topic1' => {
              '0' => { offset: 50, lag: 0 },
              '1' => { offset: 0, lag: 0 }
            }
          },
          'test-origin-group-parallel-1' => {
            'topic1' => {
              '0' => { offset: 0, lag: 0 },
              '1' => { offset: 0, lag: 0 }
            }
          }
        }
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
          expect(Karafka::Admin).to have_received(:seek_consumer_group).twice
        end
      end
    end
  end
end
