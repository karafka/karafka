# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      eofed: {
        active: true
      },
      kafka: {
        'enable.partition.eof': true
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when active flag is not boolean' do
    before { config[:eofed][:active] = rand }

    it { expect(check).not_to be_success }
  end

  context 'when eofed is enabled without enable.partition.eof' do
    let(:config) do
      {
        eofed: {
          active: true
        },
        kafka: {
          'enable.partition.eof': false
        }
      }
    end

    it { expect(check).not_to be_success }
  end
end
