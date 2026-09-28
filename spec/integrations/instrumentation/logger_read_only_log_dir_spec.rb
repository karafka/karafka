# frozen_string_literal: true

# Karafka should keep running and logging to stdout even when the log file cannot be created,
# for example on a read-only filesystem (a common setup for hardened / read-only containers).
# The default logger opens its file lazily and swallows EACCES/EROFS, so consumption must not
# crash and no log file should be created.

require "tmpdir"

strio = StringIO.new
proper_stdout = $stdout
proper_stderr = $stderr

$stdout = strio
$stderr = strio

# Pin the app root to a temp dir whose log directory is read-only, so the real logger resolves its
# log file there and fails to open it
karafka_root = Pathname.new(Dir.mktmpdir("karafka-ro"))
read_only_log_dir = karafka_root.join("log")
FileUtils.mkdir_p(read_only_log_dir)
FileUtils.chmod(0o500, read_only_log_dir)

Karafka.instance_variable_set(:@root, karafka_root)

log_file = read_only_log_dir.join("#{Karafka.env}.log")

marker = "read-only-log-marker-#{SecureRandom.hex(6)}"

setup_karafka do |config|
  # Use the real Karafka logger (built now, after $stdout was redirected) so its lazy file target
  # points at the read-only log directory
  config.logger = Karafka::Instrumentation::Logger.new
end

Consumer = Class.new(Karafka::BaseConsumer) do
  define_method(:consume) do
    Karafka.logger.error(marker)
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

$stdout = proper_stdout
$stderr = proper_stderr

# Consumption completed without crashing and the log still reached stdout
assert DT.key?(:done)
assert strio.string.include?(marker), "expected the log marker on stdout"

# The log file was never created on the read-only filesystem
assert !log_file.exist?, "log file should not be created on a read-only filesystem"

FileUtils.chmod(0o700, read_only_log_dir)
FileUtils.rm_rf(karafka_root)
