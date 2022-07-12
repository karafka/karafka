# frozen_string_literal: true

RSpec.describe_current do
  subject(:colorized) { colorized_class.new }

  let(:colorized_class) do
    Class.new do
      include Karafka::Helpers::Colorize
    end
  end

  describe '#green' do
    let(:string) { rand.to_s }

    it 'expect to colorize given string' do
      expect(colorized.green(string)).to eq("\033[0;32m#{string}\033[0m")
    end
  end

  describe '#red' do
    let(:string) { rand.to_s }

    it 'expect to colorize given string' do
      expect(colorized.red(string)).to eq("\033[0;31m#{string}\033[0m")
    end
  end
end
