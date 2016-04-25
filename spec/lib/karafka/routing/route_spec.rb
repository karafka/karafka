require 'spec_helper'

RSpec.describe Karafka::Routing::Route do
  subject { described_class.new }

  let(:group) { rand.to_s }
  let(:topic) { rand.to_s }

  describe '#build' do
    it 'expect to eager load all the attributes' do
      expect(subject)
        .to receive(:worker)

      expect(subject)
        .to receive(:parser)

      expect(subject)
        .to receive(:interchanger)

      expect(subject)
        .to receive(:group)

      expect(subject.build).to eq subject
    end
  end

  describe '#group=' do
    it { expect { subject.group = group }.not_to raise_error }
  end

  describe '#group' do
    before do
      subject.group = group
      subject.topic = topic
    end

    context 'when group is not set' do
      let(:group) { nil }

      it 'expect to build group from app name and topic' do
        expect(subject.group).to eq "#{Karafka::App.config.name.underscore}_#{topic}".to_s
      end
    end

    context 'when group is set' do
      it { expect(subject.group).to eq group }
    end
  end

  describe '#topic=' do
    it { expect { subject.topic = topic }.not_to raise_error }
  end

  describe '#topic' do
    let(:topic) { rand }

    before { subject.topic = topic }

    it 'expect to return stringified topic' do
      expect(subject.topic).to eq topic.to_s
    end
  end

  describe '#worker=' do
    let(:worker) { double }

    it { expect { subject.worker = worker }.not_to raise_error }
  end

  describe '#worker' do
    let(:controller) { double }

    before do
      subject.worker = worker
      subject.controller = controller
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

        expect(subject.worker).to eq built_worker
      end
    end

    context 'when worker is set' do
      let(:worker) { double }

      it { expect(subject.worker).to eq worker }
    end
  end

  describe '#parser=' do
    let(:parser) { double }

    it { expect { subject.parser = parser }.not_to raise_error }
  end

  describe '#parser' do
    before { subject.parser = parser }

    context 'when parser is not set' do
      let(:parser) { nil }

      it 'expect to use default one' do
        expect(subject.parser).to eq JSON
      end
    end

    context 'when parser is set' do
      let(:parser) { double }

      it { expect(subject.parser).to eq parser }
    end
  end

  describe '#interchanger=' do
    let(:interchanger) { double }

    it { expect { subject.interchanger = interchanger }.not_to raise_error }
  end

  describe '#interchanger' do
    before { subject.interchanger = interchanger }

    context 'when interchanger is not set' do
      let(:interchanger) { nil }

      it 'expect to use default one' do
        expect(subject.interchanger).to eq Karafka::Params::Interchanger
      end
    end

    context 'when interchanger is set' do
      let(:interchanger) { double }

      it { expect(subject.interchanger).to eq interchanger }
    end
  end

  describe '#validate!' do
    before { subject.topic = topic }

    context 'when topic name is invalid' do
      %w(
        & /31 ół !@
      ).each do |topic_name|
        let(:topic) { topic_name }

        it { expect { subject.validate! }.to raise_error(Karafka::Errors::InvalidTopicName) }
      end
    end

    context 'when topic name is valid' do
      let(:topic) { rand(1000).to_s }

      before { subject.group = group }

      context 'but group name is invalid' do
        %w(
          & /31 ół !@
        ).each do |group_name|
          let(:group) { group_name }

          it { expect { subject.validate! }.to raise_error(Karafka::Errors::InvalidGroupName) }
        end
      end

      context 'and group name is valid' do
        let(:group) { rand(1000).to_s }

        it { expect { subject.validate! }.not_to raise_error }
      end
    end
  end
end
