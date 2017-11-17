# frozen_string_literal: true

RSpec.describe Karafka::Responders::Builder do
  subject(:builder) { described_class.new(controller_class) }

  describe '#build' do
    context 'when we use anonymous controller' do
      let(:controller_class) { Class.new }

      it { expect(builder.build).to eq nil }
    end

    context 'when we use named controller' do
      context 'when matching responder exists' do
        let(:responder_class) { class MatchingResponder; self end }
        let(:controller_class) { class MatchingController; self end }

        before { responder_class }

        it { expect(builder.build).to eq responder_class }
      end

      context 'when no matching responder' do
        let(:controller_class) { class Matching2Controller; self end }

        it { expect(builder.build).to eq nil }
      end
    end
  end
end
