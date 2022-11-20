# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      dead_letter_queue: {
        active: true,
        topic: 'deads',
        max_retries: 5
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when active flag is not boolean' do
    before { config[:dead_letter_queue][:active] = rand }

    it { expect(check).not_to be_success }
  end

  context 'when topic is in an invalid format' do
    before { config[:dead_letter_queue][:topic] = '#$%^&*(' }

    it { expect(check).not_to be_success }
  end

  context 'when topic is not a string' do
    before { config[:dead_letter_queue][:topic] = 0 }

    it { expect(check).not_to be_success }
  end

  context 'when topic is a false' do
    before { config[:dead_letter_queue][:topic] = false }

    it { expect(check).to be_success }
  end

  context 'when max_retries is not an integer' do
    before { config[:dead_letter_queue][:max_retries] = 'invalid' }

    it { expect(check).not_to be_success }
  end

  context 'when max_retries is less than zero' do
    before { config[:dead_letter_queue][:max_retries] = -1 }

    it { expect(check).not_to be_success }
  end

  context 'when max_retries is zero' do
    before { config[:dead_letter_queue][:max_retries] = 0 }

    it { expect(check).to be_success }
  end

  context 'when topic is nil and not active' do
    before do
      config[:dead_letter_queue][:topic] = nil
      config[:dead_letter_queue][:active] = false
    end

    it { expect(check).to be_success }
  end
end
