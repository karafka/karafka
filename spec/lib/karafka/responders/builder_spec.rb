# frozen_string_literal: true

RSpec.describe Karafka::Responders::Builder do
  subject(:builder) { described_class.new(consumer_class) }

  describe '#build' do
    context 'when we use anonymous consumer' do
      let(:consumer_class) { Class.new }

      it { expect(builder.build).to eq nil }
    end

    context 'when we use named consumer' do
      context 'when matching responder exists' do
        let(:responder_class) { class MatchingResponder; self end }
        let(:consumer_class) { class MatchingConsumer; self end }

        before { responder_class }

        it { expect(builder.build).to eq responder_class }
      end

      context 'when no matching responder' do
        let(:consumer_class) { class Matching2Consumer; self end }

        it { expect(builder.build).to eq nil }
      end
    end
  end
end
