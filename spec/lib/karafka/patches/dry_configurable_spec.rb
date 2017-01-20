RSpec.describe Karafka::Patches::DryConfigurable do
  context 'root level' do
    let(:dummy_class) do
      ClassBuilder.build do
        extend Dry::Configurable

        setting :a
        setting :b
      end
    end

    subject(:config) { dummy_class.config }

    describe 'non proc example' do
      before do
        dummy_class.configure do |config|
          config.a = 3
          config.b = '4'
        end
      end

      it 'expect to store and return values' do
        expect(config.a).to eq 3
        expect(config.b).to eq '4'
      end
    end

    describe 'proc values' do
      before do
        dummy_class.configure do |config|
          config.a = -> { 1 }
          config.b = -> { 2 }
        end
      end

      it 'expect to store and return values' do
        expect(config.a).to eq 1
        expect(config.b).to eq 2
      end
    end
  end

  context 'nestings' do
    let(:dummy_class) do
      ClassBuilder.build do
        extend Dry::Configurable

        setting :a do
          setting :b
        end

        setting :c do
          setting :d
        end
      end
    end

    subject(:config) { dummy_class.config }

    describe 'non proc example' do
      before do
        dummy_class.configure do |config|
          config.a.b = 3
          config.c.d = '4'
        end
      end

      it 'expect to store and return values' do
        expect(config.a.b).to eq 3
        expect(config.c.d).to eq '4'
      end
    end

    describe 'proc values' do
      before do
        dummy_class.configure do |config|
          config.a.b = -> { 1 }
          config.c.d = -> { 2 }
        end
      end

      it 'expect to store and return values' do
        expect(config.a.b).to eq 1
        expect(config.c.d).to eq 2
      end
    end
  end
end
