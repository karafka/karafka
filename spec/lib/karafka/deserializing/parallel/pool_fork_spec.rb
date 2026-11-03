# frozen_string_literal: true

RSpec.describe Karafka::Deserializing::Parallel::Pool, mode: :fork do
  subject(:pool) { described_class.instance }

  let(:deserializer) do
    Class.new do
      def call(message)
        message.raw_payload.upcase
      end
    end.new.freeze
  end
  let(:distributor) { Karafka::Deserializing::Parallel::Distributor.new }
  let(:messages) do
    Array.new(100) do |i|
      instance_double(Karafka::Messages::Message, raw_payload: "payload_#{i}")
    end
  end

  before { pool.reset! }

  after { pool.reset! }

  if RUBY_VERSION >= "4.0"
    context "when dispatching from a process forked after the pool was started" do
      before { pool.start(2, min_payloads: 50) }

      it "deserializes with workers of the forked process" do
        reader, writer = IO.pipe

        pid = fork do
          reader.close
          result = Timeout.timeout(5) do
            pool.dispatch_async(messages, deserializer, distributor).retrieve
          end
          writer.write(result.first)
          writer.close
          exit!(0)
        rescue Timeout::Error
          exit!(1)
        end

        writer.close
        Process.wait(pid)

        expect($CHILD_STATUS.exitstatus).to eq(0)
        expect(reader.read).to eq("PAYLOAD_0")
      end
    end
  end
end
