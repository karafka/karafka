# frozen_string_literal: true

require "net/http"
require "karafka/instrumentation/vendors/kubernetes/base_listener"

# This is fully covered in the integration suite
RSpec.describe_current do
  subject(:listener) { described_class.new }

  describe "events mapping" do
    it { expect(NotificationsChecker.valid?(listener)).to be(true) }
  end

  describe "#healthy?" do
    it { expect { listener.healthy? }.to raise_error(NotImplementedError) }
  end

  describe "HTTP server" do
    subject(:listener) { listener_class.new(hostname: "127.0.0.1", port: port) }

    let(:port) { 9_031 }
    let(:listener_class) do
      Class.new(described_class) do
        def healthy?
          true
        end
      end
    end

    let(:probe) do
      lambda do
        client = Net::HTTP.new("127.0.0.1", port)
        client.open_timeout = 3
        client.read_timeout = 3
        client.request(Net::HTTP::Get.new("/")).code
      end
    end

    before { listener.send(:start) }

    after { listener.send(:stop) }

    it { expect(probe.call).to eq("200") }

    context "when an idle client is connected" do
      let(:idle) { TCPSocket.new("127.0.0.1", port) }

      after { idle.close }

      it "still responds to the next probe" do
        idle
        expect(probe.call).to eq("200")
      end

      it "closes the idle connection" do
        expect(idle.wait_readable(3)).to eq(idle)
        expect(idle.read).to eq("")
      end
    end

    context "when a client sends a too long request line" do
      let(:client) { TCPSocket.new("127.0.0.1", port) }

      let(:response) do
        client.write("GET /#{"a" * 10_000} HTTP/1.1\r\n\r\n")
        client.wait_readable(3)
        client.read
      rescue Errno::ECONNRESET, Errno::EPIPE
        ""
      end

      after { client.close }

      it "closes the connection without a response and keeps serving" do
        expect(response).to eq("")
        expect(probe.call).to eq("200")
      end
    end

    context "when a client disconnects before sending anything" do
      it "keeps serving" do
        TCPSocket.new("127.0.0.1", port).close
        expect(probe.call).to eq("200")
      end
    end
  end
end
