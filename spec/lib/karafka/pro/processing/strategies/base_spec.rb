# frozen_string_literal: true

RSpec.describe_current do
  subject(:runner) do
    mod = described_class

    klass = Class.new do
      include mod
    end

    klass.new
  end

  describe '#handle_before_schedule' do
    it { expect { runner.handle_before_schedule }.to raise_error(NotImplementedError) }
  end

  describe '#handle_after_consume' do
    it { expect { runner.handle_after_consume }.to raise_error(NotImplementedError) }
  end

  describe '#handle_revoked' do
    it { expect { runner.handle_revoked }.to raise_error(NotImplementedError) }
  end
end
