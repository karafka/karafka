require 'spec_helper'

RSpec.describe Karafka::Cli::Base do
  describe 'instance methods' do
    let(:cli) { Karafka::Cli.new }
    subject { described_class.new(cli) }

    describe '#cli' do
      it { expect(subject.cli).to eq cli }
    end
  end

  describe 'class methods' do
    subject { described_class }

    describe '#name' do
      it { expect(subject.send(:name)).to eq 'base' }
    end

    describe '#bind_to' do
      let(:name) { "name#{rand(1000)}" }
      let(:desc) { rand.to_s }
      let(:options) { { rand => rand } }
      let(:cli_class) { Karafka::Cli }

      before do
        subject.desc = desc
        subject.options = options

        allow(subject)
          .to receive(:name)
          .and_return(name)
      end

      it 'expect to use thor api to define proper action' do
        subject.bind_to(cli_class)

        expect(cli_class.instance_methods).to include name.to_sym

        expect { cli_class.new.send(name) }.to raise_error(NotImplementedError)
      end
    end
  end
end
