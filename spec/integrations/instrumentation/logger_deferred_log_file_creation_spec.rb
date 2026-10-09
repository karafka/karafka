# frozen_string_literal: true

# The default logger should not create the log directory or file until something is actually
# logged. A process that consumes without logging must leave no `log/` behind, and the first
# real log write must still create the file.

require "tmpdir"

strio = StringIO.new
proper_stdout = $stdout
proper_stderr = $stderr

$stdout = strio
$stderr = strio

# Pin the app root to a writable temp dir, so the real logger resolves its log file there
karafka_root = Pathname.new(Dir.mktmpdir("karafka-lazy-log"))
log_dir = karafka_root.join("log")
log_file = log_dir.join("#{Karafka.env}.log")

Karafka.instance_variable_set(:@root, karafka_root)

marker = "deferred-log-marker-#{SecureRandom.hex(6)}"

setup_karafka do |config|
  # Use the real Karafka logger (built now, after $stdout was redirected) so its lazy file target
  # points at the temp root
  config.logger = Karafka::Instrumentation::Logger.new
end

# `setup_karafka` switches the logger to debug, so we silence it after the setup to have a run in
# which nothing is logged
Karafka.logger.level = Logger::FATAL

Consumer = Class.new(Karafka::BaseConsumer) do
  def consume
    DT[:done] = true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

produce(DT.topic, "1")

start_karafka_and_wait_until do
  DT.key?(:done)
end

log_dir_created_before_logging = log_dir.exist?

# The first real log write creates the file, so creation was deferred and not disabled
Karafka.logger.fatal(marker)
# The log file is buffered, so we close the logger to flush it (stdout side is our StringIO)
Karafka.logger.close

$stdout = proper_stdout
$stderr = proper_stderr

assert DT.key?(:done)
assert !log_dir_created_before_logging, "log directory should not exist before anything is logged"
assert log_file.exist?, "log file should be created on the first log write"
assert File.read(log_file).include?(marker), "expected the log marker in the log file"
assert strio.string.include?(marker), "expected the log marker on stdout"

FileUtils.rm_rf(karafka_root)
