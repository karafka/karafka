# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
