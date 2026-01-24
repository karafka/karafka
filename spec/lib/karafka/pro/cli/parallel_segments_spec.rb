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
  subject(:command) { described_class.new }

  let(:distribute_cmd) { Karafka::Pro::Cli::ParallelSegments::Distribute }
  let(:distribute_instance) { instance_double(distribute_cmd) }
  let(:collapse_cmd) { Karafka::Pro::Cli::ParallelSegments::Collapse }
  let(:collapse_instance) { instance_double(collapse_cmd) }
  let(:options) { { groups: ['test-group'], force: false } }

  before do
    allow(command)
      .to receive(:options)
      .and_return(options)
    allow(distribute_cmd)
      .to receive(:new)
      .and_return(distribute_instance)
    allow(collapse_cmd)
      .to receive(:new)
      .and_return(collapse_instance)
    allow(distribute_instance)
      .to receive(:call)
    allow(collapse_instance)
      .to receive(:call)
  end

  describe '#call' do
    context 'when action is "distribute"' do
      it 'initializes Distribute with options and calls it' do
        command.call('distribute')

        expect(distribute_cmd).to have_received(:new).with(options)
        expect(distribute_instance).to have_received(:call)
      end

      it 'assumes "distribute" as default action when none provided' do
        command.call

        expect(distribute_cmd).to have_received(:new).with(options)
        expect(distribute_instance).to have_received(:call)
      end
    end

    context 'when action is "collapse"' do
      it 'initializes Collapse with options and calls it' do
        command.call('collapse')

        expect(collapse_cmd).to have_received(:new).with(options)
        expect(collapse_instance).to have_received(:call)
      end
    end

    context 'when action is "reset"' do
      it 'calls both collapse and distribute in sequence' do
        command.call('reset')

        expect(collapse_cmd).to have_received(:new).with(options)
        expect(collapse_instance).to have_received(:call)
        expect(distribute_cmd).to have_received(:new).with(options)
        expect(distribute_instance).to have_received(:call)
      end
    end

    context 'when action is invalid' do
      it 'raises ArgumentError with appropriate message' do
        expect { command.call('invalid_action') }.to raise_error(
          ArgumentError,
          'Invalid topics action: invalid_action'
        )
      end
    end
  end
end
