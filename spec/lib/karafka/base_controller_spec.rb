require 'spec_helper'

RSpec.describe Karafka::BaseController do
  let(:working_class) do
    ClassBuilder.inherit(described_class) do
      self.group = rand
      self.topic = rand

      def perform; end
    end
  end

  subject { ClassBuilder.inherit(described_class) }

  describe 'initial exceptions' do
    context 'when kafka group is not defined' do
      it 'should raise an exception' do
        expect { subject.new }.to raise_error(described_class::GroupNotDefined)
      end
    end

    context 'when kafka topic is not defined' do
      subject do
        ClassBuilder.inherit(described_class) do
          self.group = rand
        end
      end

      it 'should raise an exception' do
        expect { subject.new }.to raise_error(described_class::TopicNotDefined)
      end
    end

    context 'when perform method is not defined' do
      subject do
        ClassBuilder.inherit(described_class) do
          self.group = rand
          self.topic = rand
        end
      end

      it 'should raise an exception' do
        expect { subject.new }.to raise_error(described_class::PerformMethodNotDefined)
      end
    end

    context 'when all options are defined' do
      subject do
        ClassBuilder.inherit(described_class) do
          self.group = rand
          self.topic = rand

          def perform; end
        end
      end

      it 'should not raise an exception' do
        expect { subject.new }.not_to raise_error
      end
    end
  end

  describe '#call' do
    context 'when there are no callbacks' do
      subject { working_class.new }

      it 'should just execute enqueue' do
        expect(subject).to receive(:enqueue)

        subject.call
      end
    end
  end

  describe '#params=' do
    subject do
      ClassBuilder.inherit(described_class) do
        self.group = rand
        self.topic = rand

        before_enqueue do
          false
        end

        def perform; end
      end.new
    end

    let(:params) { { rand => rand } }

    it 'should merge controller specific options into params' do
      subject.params = params

      expected = params.merge(
        controller: subject.class,
        topic: subject.class.topic
      )

      expect(subject.send(:params)).to eq expected
    end
  end

  context 'when we have a block based before_enqueue' do
    context 'and it returns false' do
      subject do
        ClassBuilder.inherit(described_class) do
          self.group = rand
          self.topic = rand

          before_enqueue do
            false
          end

          def perform; end
        end.new
      end

      it 'should not enqueue' do
        expect(subject).not_to receive(:enqueue)

        subject.call
      end
    end

    context 'and it does not return false' do
      subject do
        ClassBuilder.inherit(described_class) do
          self.group = rand
          self.topic = rand

          before_enqueue do
            true
          end

          def perform; end
        end.new
      end

      let(:params) { double }

      it 'should enqueue' do
        expect(subject).to receive(:enqueue)

        subject.call
      end

      it 'enqueue perform function' do
        expect(subject)
          .to receive(:params)
          .and_return(params)

        expect(Karafka::Worker)
          .to receive(:perform_async)
          .with(params)

        subject.call
      end
    end
  end

  context 'when we have a method based before_enqueue' do
    context 'and it returns false' do
      subject do
        ClassBuilder.inherit(described_class) do
          self.group = rand
          self.topic = rand

          before_enqueue :method

          def perform; end

          def method
            false
          end
        end.new
      end

      it 'should not enqueue' do
        expect(subject).not_to receive(:enqueue)

        subject.call
      end
    end

    context 'and it does not return false' do
      subject do
        ClassBuilder.inherit(described_class) do
          self.group = rand
          self.topic = rand

          before_enqueue :method

          def perform; end

          def method
            true
          end
        end.new
      end

      it 'should enqueue' do
        expect(subject).to receive(:enqueue)

        subject.call
      end
    end
  end
end
