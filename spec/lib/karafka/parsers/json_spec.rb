RSpec.describe Karafka::Parsers::Json do
  subject(:parser_class) { described_class }

  describe '.parse' do
    context 'when we can parse given content' do
      let(:content_source) { { rand.to_s => rand.to_s } }
      let(:content) { content_source.to_json }

      it 'expect to parse' do
        expect(parser_class.parse(content)).to eq content_source
      end
    end

    context 'when content is malformatted' do
      let(:content) { 'abc' }

      it 'expect to raise with Karafka internal parsing error' do
        expect { parser_class.parse(content) }.to raise_error(::Karafka::Errors::ParserError)
      end
    end
  end

  describe '.generate' do
    context 'when content is a string' do
      let(:content) { rand.to_s }

      it 'expect not to do anything' do
        expect(parser_class.generate(content)).to eq content
      end
    end

    context 'when content can be serialied with #to_json' do
      let(:content) { { rand.to_s => rand.to_s } }

      it 'expect to serialize it that way' do
        expect(parser_class.generate(content)).to eq content.to_json
      end
    end

    context 'when content cannot be serialied with #to_json' do
      let(:content) { instance_double(Class, respond_to?: false) }

      it 'expect to raise parsing error' do
        expect { parser_class.generate(content) }.to raise_error(::Karafka::Errors::ParserError)
      end
    end
  end
end
