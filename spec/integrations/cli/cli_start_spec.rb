# frozen_string_literal: true

# Karafka CLI should work and should just run help without command

failed = false

begin
  Karafka::Cli.start
rescue Karafka::Errors::UnrecognizedCommandError
  failed = true
end

assert !failed
