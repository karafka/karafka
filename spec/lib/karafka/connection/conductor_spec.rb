# frozen_string_literal: true

RSpec.describe_current do
  subject(:client) { described_class.new(500) }

  describe '#wait and #signal' do
    context 'when there was a signal' do
      before { client.signal }

      it 'expect not to wait for 500ms' do
        before = Time.now.to_f
        client.wait
        after = Time.now.to_f

        expect(after - before).to be < 0.5
      end
    end

    context 'when there was no signal' do
      it 'expect to wait for 500ms' do
        before = Time.now.to_f
        client.wait
        after = Time.now.to_f

        expect(after - before).to be >= 0.5
      end
    end
  end
end
