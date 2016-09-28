RSpec.describe Karafka::Responders::Builder do
  subject(:builder) { described_class.new(controller_class) }

  describe '#build' do
    context 'anonymous controller' do
      let(:controller_class) { Class.new }

      it { expect(builder.build).to eq nil }
    end

    context 'named controller' do
      context 'matching responder exists' do
        let(:responder_class) { class MatchingResponder; end }
        let(:controller_class) { class MatchingController; end }

        it { expect(builder.build).to eq responder_class }
      end

      context 'no matching responder' do
        let(:controller_class) { class Matching2Controller; end }

        it { expect(builder.build).to eq nil }
      end
    end
  end
end
