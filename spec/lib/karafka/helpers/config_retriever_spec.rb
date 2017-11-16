# frozen_string_literal: true

RSpec.describe Karafka::Helpers::ConfigRetriever do
  context 'when a given attribute accessor is already defined' do
    subject(:extended_instance) do
      described = described_class

      klass = ClassBuilder.build do
        extend described

        # @return [Integer] example timeout
        def session_timeout
          @session_timeout ||= 10
        end

        config_retriever_for :session_timeout
      end

      klass.new
    end

    context 'when we use default value' do
      it { expect(extended_instance.session_timeout).to eq 10 }
    end

    context 'when we use overwriten value' do
      let(:new_value) { rand }

      before { extended_instance.session_timeout = new_value }

      it { expect(extended_instance.session_timeout).to eq new_value }
    end
  end

  context 'when a given attribute accessor is not defined' do
    context 'when we want to use kafka config scope' do
      subject(:extended_instance) do
        described = described_class

        klass = ClassBuilder.build do
          extend described

          config_retriever_for :session_timeout
        end

        klass.new
      end

      context 'when we assign value' do
        let(:new_value) { rand }

        before { extended_instance.session_timeout = new_value }

        it { expect(extended_instance.session_timeout).to eq new_value }
      end

      context 'when we get default value' do
        let(:default_value) { Karafka::App.config.kafka.session_timeout }

        it { expect(extended_instance.session_timeout).to eq default_value }
      end
    end

    context 'when we want to use main config scope' do
      subject(:extended_instance) do
        described = described_class

        klass = ClassBuilder.build do
          extend described

          config_retriever_for :client_id
        end

        klass.new
      end

      context 'when we assign value' do
        let(:new_value) { rand }

        before { extended_instance.client_id = new_value }

        it { expect(extended_instance.client_id).to eq new_value }
      end

      context 'when we use default value' do
        let(:default_value) { Karafka::App.config.client_id }

        it { expect(extended_instance.client_id).to eq default_value }
      end
    end
  end
end
