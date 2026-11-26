# frozen_string_literal: true

# When `karafka server` stops forcefully, the default logger output written before the
# `Kernel.exit!` (including the forceful shutdown details) should reach both the piped stdout
# and the log file. `exit!` skips the IO finalizers, so unflushed buffers would be lost.

require "digest"
require "securerandom"
require "timeout"

SPEC_HASH = Digest::MD5.hexdigest(
  "spec/integrations/shutdown/forceful_shutdown_keeps_logs_poro/forceful_shutdown_keeps_logs_spec.rb"
)[0, 6]
TOPIC = "it-#{SPEC_HASH}-#{SecureRandom.hex(6)}".freeze
MARKER = File.expand_path("consuming")
LOG_PATH = File.expand_path("log/development.log")

File.write("karafka.rb", <<~RUBY)
  # frozen_string_literal: true

  class SlowConsumer < Karafka::BaseConsumer
    def consume
      File.write(#{MARKER.inspect}, "1")
      # Longer than the shutdown timeout, so the stop is forceful
      sleep(30)
    end
  end

  class KarafkaApp < Karafka::App
    setup do |config|
      config.kafka = { "bootstrap.servers": "127.0.0.1:9092" }
      config.client_id = #{SecureRandom.hex(6).inspect}
      config.shutdown_timeout = 2_000
    end

    routes.draw do
      topic #{TOPIC.inspect} do
        consumer SlowConsumer
        config(partitions: 1)
      end
    end
  end

  Karafka.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)

  Karafka.monitor.subscribe("app.running") do
    Karafka.producer.produce_sync(topic: #{TOPIC.inspect}, payload: "1")
  end
RUBY

env = { "KARAFKA_ENV" => "development" }

migrate = system(env, "bundle exec karafka topics migrate", out: File::NULL, err: File::NULL)
raise "topics migrate failed" unless migrate

reader, writer = IO.pipe
pid = Process.spawn(env, "bundle exec karafka server", out: writer, err: writer)
writer.close
output = Thread.new { reader.read }

Timeout.timeout(60) { sleep(0.1) until File.exist?(MARKER) }
Process.kill("TERM", pid)
_, status = Timeout.timeout(60) { Process.wait2(pid) }
stdout = output.value

raise "Expected exit code 2, got #{status.exitstatus}: #{stdout}" unless status.exitstatus == 2

[["stdout", stdout], ["log file", File.read(LOG_PATH)]].each do |name, content|
  %w[Stopping\ Karafka\ server Forceful\ Karafka\ server\ stop].each do |line|
    raise "Expected #{line.inspect} in #{name}: #{content}" unless content.include?(line)
  end
end
