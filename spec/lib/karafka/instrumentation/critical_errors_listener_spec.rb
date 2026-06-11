# frozen_string_literal: true

RSpec.describe_current do
  subject(:listener) { described_class.instance }

  let(:event) { { error: error } }
  let(:error) { SystemExit.new }

  before do
    allow(Karafka::Server).to receive(:stop)
    allow(Karafka::App).to receive_messages(
      stopping?: false,
      stopped?: false,
      terminated?: false
    )

    # Run the shutdown thread block in a joined real thread so the examples are deterministic
    # and no thread outlives the stubs
    allow(Thread).to receive(:new) do |&block|
      Thread.start(&block).join
    end
  end

  context "when the error is process-critical" do
    it "expect to initiate a graceful shutdown" do
      listener.on_error_occurred(event)

      expect(Karafka::Server).to have_received(:stop)
    end
  end

  context "when the error is a regular error" do
    let(:error) { StandardError.new }

    it "expect not to initiate a shutdown" do
      listener.on_error_occurred(event)

      expect(Karafka::Server).not_to have_received(:stop)
    end
  end

  context "when the error is a non-critical non-StandardError" do
    let(:error) { NotImplementedError.new }

    it "expect not to initiate a shutdown" do
      listener.on_error_occurred(event)

      expect(Karafka::Server).not_to have_received(:stop)
    end
  end

  context "when shutdown is already in motion" do
    before { allow(Karafka::App).to receive(:stopping?).and_return(true) }

    it "expect not to initiate another stop" do
      listener.on_error_occurred(event)

      expect(Karafka::Server).not_to have_received(:stop)
    end
  end

  context "when the app is quieting" do
    # Quiet states park the process but do not stop it - a critical error there must still
    # escalate, which is why the guard does not use the broader `App.done?`
    before { allow(Karafka::App).to receive_messages(quieting?: true, quiet?: true) }

    it "expect to still initiate a graceful shutdown" do
      listener.on_error_occurred(event)

      expect(Karafka::Server).to have_received(:stop)
    end
  end

  context "when a user-defined class is configured as critical" do
    let(:custom_error_class) { Class.new(StandardError) }
    let(:error) { custom_error_class.new }

    before { allow(listener).to receive(:critical_errors).and_return([custom_error_class]) }

    it "expect to initiate a graceful shutdown" do
      listener.on_error_occurred(event)

      expect(Karafka::Server).to have_received(:stop)
    end
  end

  context "when spawning the shutdown thread itself fails" do
    before { allow(Thread).to receive(:new).and_raise(ThreadError) }

    it "expect not to let the error escape into the reporting flow" do
      expect { listener.on_error_occurred(event) }.not_to raise_error
    end
  end
end
