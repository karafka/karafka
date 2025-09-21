# frozen_string_literal: true

RSpec.describe Karafka::Connection::Mode do
  subject(:mode_instance) { described_class.new(mode) }

  let(:mode) { :subscribe }

  describe '#initialize' do
    context 'when valid mode is provided' do
      %i[subscribe assign].each do |valid_mode|
        context "when mode is #{valid_mode}" do
          let(:mode) { valid_mode }

          it 'initializes correctly' do
            expect { mode_instance }.not_to raise_error
            expect(mode_instance.send("#{valid_mode}?")).to be(true)
          end
        end
      end
    end

    context 'when invalid mode is provided' do
      let(:mode) { :invalid }

      it 'raises ArgumentError' do
        expect { mode_instance }.to raise_error(
          ArgumentError,
          'Invalid connection mode: invalid. Valid modes: subscribe, assign'
        )
      end
    end

    context 'when no mode is provided' do
      subject(:mode_instance) { described_class.new }

      it 'defaults to subscribe' do
        expect(mode_instance.subscribe?).to be(true)
      end
    end
  end

  describe 'query methods' do
    %i[subscribe assign].each do |mode_name|
      describe "##{mode_name}?" do
        context "when mode is #{mode_name}" do
          let(:mode) { mode_name }

          it 'returns true' do
            expect(mode_instance.send("#{mode_name}?")).to be(true)
          end

          it 'returns false for other modes' do
            other_modes = %i[subscribe assign] - [mode_name]
            other_modes.each do |other_mode|
              expect(mode_instance.send("#{other_mode}?")).to be(false)
            end
          end
        end
      end
    end
  end

  describe 'setter methods' do
    %i[subscribe assign].each do |mode_name|
      describe "##{mode_name}!" do
        it "sets mode to #{mode_name}" do
          mode_instance.send("#{mode_name}!")
          expect(mode_instance.send("#{mode_name}?")).to be(true)
        end

        it 'returns the mode symbol' do
          expect(mode_instance.send("#{mode_name}!")).to eq(mode_name)
        end
      end
    end
  end

  describe '#to_s' do
    context 'when mode is assign' do
      let(:mode) { :assign }

      it 'returns string representation' do
        expect(mode_instance.to_s).to eq('assign')
      end
    end

    context 'when mode is subscribe' do
      let(:mode) { :subscribe }

      it 'returns string representation' do
        expect(mode_instance.to_s).to eq('subscribe')
      end
    end
  end

  describe '#to_sym' do
    context 'when mode is assign' do
      let(:mode) { :assign }

      it 'returns symbol representation' do
        expect(mode_instance.to_sym).to eq(:assign)
      end
    end

    context 'when mode is subscribe' do
      let(:mode) { :subscribe }

      it 'returns symbol representation' do
        expect(mode_instance.to_sym).to eq(:subscribe)
      end
    end
  end

  describe 'state transitions' do
    it 'allows multiple state changes' do
      expect(mode_instance.subscribe?).to be(true)

      mode_instance.assign!
      expect(mode_instance.assign?).to be(true)

      mode_instance.subscribe!
      expect(mode_instance.subscribe?).to be(true)
    end
  end
end
