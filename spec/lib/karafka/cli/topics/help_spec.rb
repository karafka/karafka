# frozen_string_literal: true

RSpec.describe_current do
  subject(:help_topics) { described_class.new }

  describe "#call" do
    before do
      # Suppress console output during tests
      allow(help_topics).to receive(:puts)
    end

    it "displays the help message and returns false" do
      expect(help_topics.call).to be_falsey
    end

    it "outputs the complete help text with all commands" do
      help_topics.call

      expected_commands = [
        "align        # Aligns configuration of all declarative topics based on definitions",
        "create       # Creates topics with appropriate settings",
        "delete       # Deletes all topics defined in the routes",
        "help         # Describes available topics management commands",
        "migrate      # Creates missing topics, repartitions existing and aligns configuration",
        "plan         # Plans migration process and prints changes to be applied",
        "repartition  # Adds additional partitions to topics with fewer partitions than expected",
        "reset        # Deletes and re-creates all topics"
      ]

      expected_commands.each do |command_line|
        expect(help_topics).to have_received(:puts).with(
          a_string_including(command_line)
        )
      end
    end

    it "outputs options section with detailed exit code information" do
      help_topics.call

      expect(help_topics).to have_received(:puts).with(
        a_string_including("--detailed-exitcode  # Provides detailed exit codes")
      )
    end

    it "outputs examples section with common usage patterns" do
      help_topics.call

      expected_examples = [
        "karafka topics create",
        "karafka topics plan --detailed-exitcode",
        "karafka topics migrate",
        "karafka topics align"
      ]

      expected_examples.each do |example|
        expect(help_topics).to have_received(:puts).with(
          a_string_including(example)
        )
      end
    end

    it "outputs the cluster limitation note" do
      help_topics.call

      expect(help_topics).to have_received(:puts).with(
        a_string_including("Note: All admin operations run on the default cluster only.")
      )
    end

    it "outputs the complete help structure with proper sections" do
      help_topics.call

      expect(help_topics).to have_received(:puts).with(
        a_string_including("Karafka topics commands:")
      )
      expect(help_topics).to have_received(:puts).with(
        a_string_including("Options:")
      )
      expect(help_topics).to have_received(:puts).with(
        a_string_including("Examples:")
      )
    end

    context "when called multiple times" do
      it "consistently returns false" do
        expect(help_topics.call).to be_falsey
        expect(help_topics.call).to be_falsey
        expect(help_topics.call).to be_falsey
      end

      it "outputs help text each time" do
        3.times { help_topics.call }

        expect(help_topics).to have_received(:puts).exactly(3).times
      end
    end

    context "when checking output format" do
      it "outputs a single heredoc string" do
        help_topics.call

        # Should be called exactly once with the full help text
        expect(help_topics).to have_received(:puts).once
      end

      it "includes all required sections in the output" do
        help_topics.call

        # Capture the argument passed to puts
        output = nil
        allow(help_topics).to receive(:puts) { |arg| output = arg }
        help_topics.call

        expect(output).to include("Karafka topics commands:")
        expect(output).to include("Options:")
        expect(output).to include("Examples:")
        expect(output).to include("Note:")
      end
    end

    context "when verifying return value semantics" do
      it "returns false to indicate no changes were applied" do
        # The help command should return false to indicate with exit code 0
        # that no changes were applied, consistent with other Karafka CLI commands
        expect(help_topics.call).to be_falsey
      end

      it "returns boolean false specifically, not nil" do
        result = help_topics.call
        expect(result).to be false
        expect(result).not_to be_nil
      end
    end
  end
end
