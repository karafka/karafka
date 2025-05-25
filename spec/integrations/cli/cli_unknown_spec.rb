# frozen_string_literal: true

# Karafka CLI should work and should fail with unknown command error

failed = false

ARGV[0] = 'unknown'

begin
  Karafka::Cli.start
rescue Karafka::Errors::UnrecognizedCommandError
  failed = true
end

assert failed
