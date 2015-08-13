require 'spec_helper'

RSpec.describe Karafka::Params do
  describe '#parse' do
    let(:options) { { a: '1' } }
    context 'params is json' do
      before do
        @parsed_params = described_class.new(options.to_json).parse
      end

      it 'deserializes as JSON' do
        expect(@parsed_params[:a]).to eq '1'
      end

      it 'returns hashWithIndifferentAccess' do
        expect(@parsed_params[:a]).to eq(@parsed_params['a'])
      end
    end

    context 'params is string' do
      it 'deserializes as String' do
        parsed_params = described_class.new(options.to_s).parse
        expect(parsed_params).to eq({ a: '1' }.to_s)
      end
    end
  end
end
