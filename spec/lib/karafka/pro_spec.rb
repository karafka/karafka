# frozen_string_literal: true

RSpec.describe_current do
  let(:comm) { 'This Karafka component is a Pro component under a commercial license' }
  let(:not_lgpl) { 'This Karafka component is NOT licensed under LGPL.' }
  let(:usage) { 'All of the commercial components are present in the' }

  Dir[Karafka.gem_root.join('lib', 'karafka', 'pro', '**/*.rb')].each do |pro_file|
    context "when checking #{pro_file}" do
      let(:content) { File.read(pro_file) }

      it { expect(content).to include(comm) }
      it { expect(content).to include(not_lgpl) }
      it { expect(content).to include(usage) }
    end
  end
end
