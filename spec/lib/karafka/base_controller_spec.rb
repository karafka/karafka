require 'spec_helper'

RSpec.describe Karafka::BaseController do
  context 'instance' do
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
      pending
    end
  end

  context 'class' do
    subject { described_class }

    describe '#before_schedule' do
      pending
    end
  end
end
