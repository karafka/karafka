# frozen_string_literal: true

# Most of the stuff is validated via the regular contract, this contract needs to only worry about
# the expanded stuff
RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      dead_letter_queue: {
        skip: :one
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when we want to skip batch' do
    before { config[:dead_letter_queue][:skip] = :batch }

    it { expect(check).to be_success }
  end

  context 'when we want to skip batch' do
    before { config[:dead_letter_queue][:skip] = :batch }

    it { expect(check).to be_success }
  end

  context 'when skip value is invalid' do
    before { config[:dead_letter_queue][:skip] = rand }

    it { expect(check).not_to be_success }
  end
end
