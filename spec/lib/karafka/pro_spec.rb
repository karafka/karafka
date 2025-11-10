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

  # Check that all integration specs have a description comment
  describe 'integration specs descriptions' do
    # Helper to check if file has a description comment
    # A description is a comment that's not:
    # - The frozen_string_literal line
    # - The pro license notice (for pro specs)
    # - Empty comment lines
    def has_description?(content, is_pro:)
      lines = content.lines

      # Find all comment lines that are not frozen_string_literal or license
      description_comments = []

      lines.each do |line|
        # Skip frozen_string_literal
        next if line.include?('frozen_string_literal')

        # Skip license notice for pro specs
        if is_pro
          next if line.include?('This code is part of Karafka Pro')
          next if line.include?('See LICENSE for details')
        end

        # Check if this is a comment line
        next unless line.strip.start_with?('#')

        stripped = line.strip[1..].strip
        # If it's a non-empty comment, add it as a potential description
        description_comments << stripped unless stripped.empty?
      end

      # We have a description if there's at least one non-license,
      # non-frozen_string_literal comment
      !description_comments.empty?
    end

    Dir[Karafka.gem_root.join('spec', 'integrations', '**/*_spec.rb')].each do |spec_file|
      context "when checking #{spec_file}" do
        let(:content) { File.read(spec_file) }
        let(:is_pro) { spec_file.include?('/pro/') }

        it 'has a description comment explaining what the spec tests' do
          expect(has_description?(content, is_pro: is_pro)).to be(true)
        end
      end
    end
  end
end
