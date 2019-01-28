# frozen_string_literal: true

RSpec.describe Karafka::Errors do
  describe 'BaseError' do
    subject(:error) { described_class::BaseError }

    specify { expect(error).to be < StandardError }
  end

  describe 'SerializationError' do
    subject(:error) { described_class::SerializationError }

    specify { expect(error).to be < described_class::BaseError }
  end

  describe 'DeserializationError' do
    subject(:error) { described_class::DeserializationError }

    specify { expect(error).to be < described_class::BaseError }
  end

  describe 'NonMatchingRouteError' do
    subject(:error) { described_class::NonMatchingRouteError }

    specify { expect(error).to be < described_class::BaseError }
  end

  describe 'InvalidConfigurationError' do
    subject(:error) { described_class::InvalidConfigurationError }

    specify { expect(error).to be < described_class::BaseError }
  end

  describe 'MissingBootFileError' do
    subject(:error) { described_class::MissingBootFileError }

    specify { expect(error).to be < described_class::BaseError }
  end
end
