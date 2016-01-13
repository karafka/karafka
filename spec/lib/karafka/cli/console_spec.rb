require 'spec_helper'

RSpec.describe Karafka::Cli do
  subject { described_class.new }

  describe '#console' do
    let(:cmd) { "KARAFKA_CONSOLE=true bundle exec irb -r #{Karafka.boot_file}" }

    it 'expect to execute irb with boot file required' do
      expect(subject)
        .to receive(:info)

      expect(subject)
        .to receive(:system)
        .with(cmd)

      subject.console
    end
  end
end
