# frozen_string_literal: true

RSpec.describe_current do
  let(:comm) { 'This code is part of Karafka Pro, a commercial component not licensed under LGPL' }
  let(:see) { 'See LICENSE for details.' }

  Dir[Karafka.gem_root.join('lib', 'karafka', 'pro', '**/*.rb')].each do |pro_file|
    context "when checking #{pro_file}" do
      let(:content) { File.read(pro_file) }

      it { expect(content).to include(comm) }
      it { expect(content).to include(see) }
    end
  end

  Dir[Karafka.gem_root.join('spec', 'lib', 'karafka', 'pro', '**/*.rb')].each do |pro_file|
    context "when checking #{pro_file}" do
      let(:content) { File.read(pro_file) }

      it { expect(content).to include(comm) }
      it { expect(content).to include(see) }
    end
  end

  Dir[Karafka.gem_root.join('spec', 'integrations', 'pro', '**/*.rb')].each do |pro_file|
    context "when checking #{pro_file}" do
      let(:content) { File.read(pro_file) }

      it { expect(content).to include(comm) }
      it { expect(content).to include(see) }
    end
  end
end
