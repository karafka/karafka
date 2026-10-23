# frozen_string_literal: true

# On a Ruby without Process.fork (e.g. JRuby), swarm mode must fail before any work with an error
# that names what is missing, both from the CLI and when the supervisor is run directly.

setup_karafka

draw_routes(create_topics: false) do
  topic "regular" do
    consumer Class.new(Karafka::BaseConsumer)
  end
end

Process.singleton_class.prepend(
  Module.new do
    def respond_to?(name, include_all = false)
      (name == :fork) ? false : super
    end
  end
)

errors = []

ARGV[0] = "swarm"

begin
  Karafka::Cli.start
rescue Karafka::Errors::UnsupportedOptionError => e
  errors << e
end

ARGV.clear

begin
  Karafka::Swarm::Supervisor.new.run
rescue Karafka::Errors::UnsupportedOptionError => e
  errors << e
end

assert_equal 2, errors.size
errors.each { |error| assert error.message.include?("JRuby"), error.message }
assert !Karafka.producer.status.closed?
assert Karafka::App.config.internal.swarm.manager.nodes.empty?
