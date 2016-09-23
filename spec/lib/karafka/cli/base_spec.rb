RSpec.describe Karafka::Cli::Base do
  describe 'instance methods' do
    let(:cli) { Karafka::Cli.new }
    subject(:base_cli) { described_class.new(cli) }

    describe '#cli' do
      it { expect(base_cli.cli).to eq cli }
    end
  end

  describe 'class methods' do
    subject(:base_cli_class) { described_class }

    describe '#name' do
      it { expect(base_cli_class.send(:name)).to eq 'base' }
    end

    describe '#bind_to' do
      let(:name) { "name#{rand(1000)}" }
      let(:desc) { rand.to_s }
      let(:options) { { rand => rand } }
      let(:cli_class) { Karafka::Cli }

      before do
        base_cli_class.desc desc
        base_cli_class.option options

        allow(base_cli_class)
          .to receive(:name)
          .and_return(name)
      end

      it 'expect to use thor api to define proper action' do
        base_cli_class.bind_to(cli_class)

        expect(cli_class.instance_methods).to include name.to_sym

        expect { cli_class.new.send(name) }.to raise_error(NotImplementedError)
      end
    end
  end
end
