module Karafka
  # Karafka framework Cli
  # If you want to add/modify command that belongs to CLI, please review all commands
  # available in cli/ directory inside Karafka source code.
  #
  # @note Whole Cli is built using Thor
  # @see https://github.com/erikhuda/thor
  class Cli < Thor
    package_name 'Karafka'
  end
end

# This is kinda trick - since we don't have a autoload and other magic stuff
# like Rails does, so instead this method allows us to exist with exitcode 10
# then our wrapping process (outside of irb) detects this, it will restart the
# console with new code loaded
# Yes we know that it is not turbofast, however it is turbo convinient and small
#
# Also - the KARAFKA_CONSOLE is used to detect that we're executing the irb session
# so this method is only available when the Karafka console is running
#
# We skip this because this should exist and be only valid in the console
# :nocov:
if ENV['KARAFKA_CONSOLE']
  # Reloads Karafka irb console session
  def reload!
    puts "Reloading...\n"
    Kernel.exit 10
  end
end
# :nocov:
