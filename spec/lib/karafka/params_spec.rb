require 'spec_helper'

RSpec.describe Karafka::Params do
  describe '#parse' do
    let(:opt) { { a: '1' } }
    subject { described_class.new(options) }

    context 'params is json' do
      let(:options) { opt.to_json }
      let(:parsed_params) { subject.parse }

      it 'deserializes as JSON' do
        expect(parsed_params[:a]).to eq '1'
      end

      it 'returns hashWithIndifferentAccess' do
        expect(parsed_params[:a]).to eq(parsed_params['a'])
      end
    end

    context 'params is string' do
      let(:options) { opt.to_s }

      it 'deserializes as String' do
        parsed_params = subject.parse
        expect(parsed_params).to eq({ a: '1' }.to_s)
      end
    end
  end
end
