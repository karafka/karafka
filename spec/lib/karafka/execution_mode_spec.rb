# frozen_string_literal: true

RSpec.describe Karafka::ExecutionMode do
  subject(:execution_mode) { described_class.new(mode) }

  let(:mode) { :standalone }

  describe '#initialize' do
    context 'when valid mode is provided' do
      %i[standalone embedded supervisor swarm].each do |valid_mode|
        context "when mode is #{valid_mode}" do
          let(:mode) { valid_mode }

          it 'initializes correctly' do
            expect { execution_mode }.not_to raise_error
            expect(execution_mode.send("#{valid_mode}?")).to be(true)
          end
        end
      end
    end

    context 'when invalid mode is provided' do
      let(:mode) { :invalid }

      it 'raises ArgumentError' do
        expect { execution_mode }.to raise_error(
          ArgumentError,
          'Invalid execution mode: invalid. Valid modes: standalone, embedded, supervisor, swarm'
        )
      end
    end

    context 'when no mode is provided' do
      subject(:execution_mode) { described_class.new }

      it 'defaults to standalone' do
        expect(execution_mode.standalone?).to be(true)
      end
    end
  end

  describe 'query methods' do
    %i[standalone embedded supervisor swarm].each do |mode_name|
      describe "##{mode_name}?" do
        context "when mode is #{mode_name}" do
          let(:mode) { mode_name }

          it 'returns true' do
            expect(execution_mode.send("#{mode_name}?")).to be(true)
          end

          it 'returns false for other modes' do
            (described_class::MODES - [mode_name]).each do |other_mode|
              expect(execution_mode.send("#{other_mode}?")).to be(false)
            end
          end
        end
      end
    end
  end

  describe 'setter methods' do
    %i[standalone embedded supervisor swarm].each do |mode_name|
      describe "##{mode_name}!" do
        it "sets mode to #{mode_name}" do
          execution_mode.send("#{mode_name}!")
          expect(execution_mode.send("#{mode_name}?")).to be(true)
        end

        it 'returns the mode symbol' do
          expect(execution_mode.send("#{mode_name}!")).to eq(mode_name)
        end
      end
    end
  end

  describe '#to_s' do
    context 'when mode is embedded' do
      let(:mode) { :embedded }

      it 'returns string representation' do
        expect(execution_mode.to_s).to eq('embedded')
      end
    end

    context 'when mode is swarm' do
      let(:mode) { :swarm }

      it 'returns string representation' do
        expect(execution_mode.to_s).to eq('swarm')
      end
    end
  end

  describe '#to_sym' do
    context 'when mode is embedded' do
      let(:mode) { :embedded }

      it 'returns symbol representation' do
        expect(execution_mode.to_sym).to eq(:embedded)
      end
    end

    context 'when mode is supervisor' do
      let(:mode) { :supervisor }

      it 'returns symbol representation' do
        expect(execution_mode.to_sym).to eq(:supervisor)
      end
    end
  end

  describe 'state transitions' do
    it 'allows multiple state changes' do
      expect(execution_mode.standalone?).to be(true)

      execution_mode.embedded!
      expect(execution_mode.embedded?).to be(true)

      execution_mode.swarm!
      expect(execution_mode.swarm?).to be(true)

      execution_mode.supervisor!
      expect(execution_mode.supervisor?).to be(true)

      execution_mode.standalone!
      expect(execution_mode.standalone?).to be(true)
    end
  end

  describe '#==' do
    context 'when comparing with symbols' do
      it 'returns true when mode matches' do
        expect(execution_mode == :standalone).to be(true)
      end

      it 'returns false when mode does not match' do
        expect(execution_mode == :embedded).to be(false)
      end
    end

    context 'when comparing with strings' do
      it 'returns true when mode matches' do
        expect(execution_mode == 'standalone').to be(true)
      end

      it 'returns false when mode does not match' do
        expect(execution_mode == 'embedded').to be(false)
      end
    end

    context 'when comparing with another ExecutionMode' do
      let(:other_mode) { described_class.new(:standalone) }

      it 'returns true when modes match' do
        expect(execution_mode == other_mode).to be(true)
      end

      it 'returns false when modes do not match' do
        other_mode.embedded!
        expect(execution_mode == other_mode).to be(false)
      end
    end

    context 'when comparing with other types' do
      it 'returns false for nil' do
        expect(execution_mode.nil?).to be(false)
      end

      it 'returns false for numbers' do
        expect(execution_mode == 123).to be(false)
      end

      it 'returns false for arrays' do
        expect(execution_mode == [:standalone]).to be(false)
      end
    end

    context 'when mode is changed' do
      it 'comparison reflects the new mode' do
        expect(execution_mode == :standalone).to be(true)
        expect(execution_mode == 'standalone').to be(true)

        execution_mode.swarm!

        expect(execution_mode == :swarm).to be(true)
        expect(execution_mode == 'swarm').to be(true)
        expect(execution_mode == :standalone).to be(false)
        expect(execution_mode == 'standalone').to be(false)
      end
    end
  end
end
