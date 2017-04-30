RSpec.describe Karafka::Routing::Route do
  subject(:route) { described_class.new }

  let(:group) { rand.to_s }
  let(:topic) { rand.to_s }

  describe '#build' do
    it 'expect to eager load all the attributes' do
      expect(route)
        .to receive(:worker)

      expect(route)
        .to receive(:parser)

      expect(route)
        .to receive(:interchanger)

      expect(route)
        .to receive(:group)

      expect(route.build).to eq route
    end
  end

  describe '#group=' do
    it { expect { route.group = group }.not_to raise_error }
  end

  describe '#group' do
    before do
      route.group = group
      route.topic = topic
    end

    context 'when group is not set' do
      let(:group) { nil }

      it 'expect to build group from app name and topic' do
        expect(route.group).to eq "#{Karafka::App.config.name.underscore}_#{topic}".to_s
      end
    end

    context 'when group is set' do
      it { expect(route.group).to eq group }
    end
  end

  describe '#topic=' do
    it { expect { route.topic = topic }.not_to raise_error }
  end

  describe '#topic' do
    let(:topic) { rand }

    before { route.topic = topic }

    it 'expect to return stringified topic' do
      expect(route.topic).to eq topic.to_s
    end
  end

  describe '#worker=' do
    let(:worker) { double }

    it { expect { route.worker = worker }.not_to raise_error }
  end

  describe '#worker' do
    let(:controller) { double }

    before do
      route.worker = worker
      route.controller = controller
    end

    context 'when inline_mode is true' do
      let(:worker) { false }

      before do
        route.inline_mode = true
      end

      it { expect(route.worker).to eq nil }
    end

    context 'when inline_mode is false' do
      before do
        route.inline_mode = false
      end

      context 'when worker is not set' do
        let(:worker) { nil }
        let(:built_worker) { double }
        let(:builder) { double }

        it 'expect to build worker using builder' do
          expect(Karafka::Workers::Builder)
            .to receive(:new)
            .with(controller)
            .and_return(builder)

          expect(builder)
            .to receive(:build)
            .and_return(built_worker)

          expect(route.worker).to eq built_worker
        end
      end
    end

    context 'when worker is set' do
      let(:worker) { double }

      it { expect(route.worker).to eq worker }
    end
  end

  describe '#inline_mode=' do
    let(:inline_mode) { double }

    it { expect { route.inline_mode = inline_mode }.not_to raise_error }
  end

  describe '#inline_mode' do
    before { route.inline_mode = inline_mode }

    context 'when inline_mode is not set' do
      let(:default_inline) { rand }
      let(:inline_mode) { nil }

      before do
        expect(Karafka::App.config).to receive(:inline_mode)
          .and_return(default_inline)
      end

      it 'expect to use Karafka::App default' do
        expect(route.inline_mode).to eq default_inline
      end
    end

    context 'when inline_mode per route is set to false' do
      let(:inline_mode) { false }

      it { expect(route.inline_mode).to eq inline_mode }
    end

    context 'when inline_mode per route is set to true' do
      let(:inline_mode) { true }

      it { expect(route.inline_mode).to eq inline_mode }
    end
  end

  describe '#responder' do
    let(:controller) { double }

    before do
      route.responder = responder
      route.controller = controller
    end

    context 'when responder is not set' do
      let(:responder) { nil }
      let(:built_responder) { double }
      let(:builder) { double }

      it 'expect to build responder using builder' do
        expect(Karafka::Responders::Builder)
          .to receive(:new)
          .with(controller)
          .and_return(builder)

        expect(builder)
          .to receive(:build)
          .and_return(built_responder)

        expect(route.responder).to eq built_responder
      end
    end

    context 'when responder is set' do
      let(:responder) { double }

      it { expect(route.responder).to eq responder }
    end
  end

  describe '#parser=' do
    let(:parser) { double }

    it { expect { route.parser = parser }.not_to raise_error }
  end

  describe '#parser' do
    before { route.parser = parser }

    context 'when parser is not set' do
      let(:parser) { nil }

      it 'expect to use default one' do
        expect(route.parser).to eq Karafka::Parsers::Json
      end
    end

    context 'when parser is set' do
      let(:parser) { double }

      it { expect(route.parser).to eq parser }
    end
  end

  describe '#interchanger=' do
    let(:interchanger) { double }

    it { expect { route.interchanger = interchanger }.not_to raise_error }
  end

  describe '#interchanger' do
    before { route.interchanger = interchanger }

    context 'when interchanger is not set' do
      let(:interchanger) { nil }

      it 'expect to use default one' do
        expect(route.interchanger).to eq Karafka::Params::Interchanger
      end
    end

    context 'when interchanger is set' do
      let(:interchanger) { double }

      it { expect(route.interchanger).to eq interchanger }
    end
  end

  describe '#validate!' do
    before { route.topic = topic }

    context 'when topic name is invalid' do
      %w(
        & /31 ół !@
      ).each do |topic_name|
        let(:topic) { topic_name }

        it { expect { route.validate! }.to raise_error(Karafka::Errors::InvalidTopicName) }
      end
    end

    context 'when topic name is valid' do
      let(:topic) { 'topic_123.abc-xyz' }

      before { route.group = group }

      context 'but group name is invalid' do
        %w(
          & /31 ół !@
        ).each do |group_name|
          let(:group) { group_name }

          it { expect { route.validate! }.to raise_error(Karafka::Errors::InvalidGroupName) }
        end
      end

      context 'and group name is valid' do
        let(:group) { 'topic_123.abc-xyz' }

        it { expect { route.validate! }.not_to raise_error }
      end
    end
  end
end
