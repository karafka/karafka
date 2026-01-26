# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

RSpec.describe_current do
  subject(:validator_class) do
    Class.new(described_class) do
      configure do |config|
        config.error_messages = YAML.safe_load_file(
          File.join(Karafka.gem_root, "config", "locales", "errors.yml")
        ).fetch("en").fetch("validations").fetch("test")
      end

      required(:id) { |id| id.is_a?(String) }
    end
  end

  describe "#validate!" do
    subject(:validation) { validator_class.new.validate!(data) }

    context "when data is valid" do
      let(:data) { { id: "1" } }

      it { expect { validation }.not_to raise_error }
    end

    context "when data is not valid" do
      let(:data) { { id: 1 } }

      it { expect { validation }.to raise_error(Karafka::Errors::InvalidConfigurationError) }
    end
  end
end
