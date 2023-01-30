# frozen_string_literal: true

module Karafka
  class Cli < Thor
    # Base class for all the command that we want to define
    # This base class provides a nicer interface to Thor and allows to easier separate single
    # independent commands
    # In order to define a new command you need to:
    #   - specify its desc
    #   - implement call method
    #
    # @example Create a dummy command
    #   class Dummy < Base
    #     self.desc = 'Dummy command'
    #
    #     def call
    #       puts 'I'm doing nothing!
    #     end
    #   end
    class Base
      include Thor::Shell

      # We can use it to call other cli methods via this object
      attr_reader :cli

      # @param cli [Karafka::Cli] current Karafka Cli instance
      def initialize(cli)
        @cli = cli
      end

      # This method should implement proper cli action
      def call
        raise NotImplementedError, 'Implement this in a subclass'
      end

      class << self
        # Loads proper environment with what is needed to run the CLI
        def load
          # If there is a boot file, we need to require it as we expect it to contain
          # Karafka app setup, routes, etc
          if File.exist?(::Karafka.boot_file)
            rails_env_rb = File.join(Dir.pwd, 'config/environment.rb')

            # Load Rails environment file that starts Rails, so we can reference consumers and
            # other things from `karafka.rb` file. This will work only for Rails, for non-rails
            # a manual setup is needed
            require rails_env_rb if Kernel.const_defined?(:Rails) && File.exist?(rails_env_rb)

            require Karafka.boot_file.to_s
          # However when it is unavailable, we still want to be able to run help command
          # and install command as they don't require configured app itself to run
          elsif %w[-h install].none? { |cmd| cmd == ARGV[0] }
            raise ::Karafka::Errors::MissingBootFileError, ::Karafka.boot_file
          end
        end

        # Allows to set options for Thor cli
        # @see https://github.com/erikhuda/thor
        # @param option Single option details
        def option(*option)
          @options ||= []
          @options << option
        end

        # Allows to set description of a given cli command
        # @param desc [String] Description of a given cli command
        def desc(desc)
          @desc ||= desc
        end

        # This method will bind a given Cli command into Karafka Cli
        # This method is a wrapper to way Thor defines its commands
        # @param cli_class [Karafka::Cli] Karafka cli_class
        def bind_to(cli_class)
          cli_class.desc name, @desc

          (@options || []).each { |option| cli_class.option(*option) }

          context = self

          cli_class.send :define_method, name do |*args|
            context.new(self).call(*args)
          end
        end

        private

        # @return [String] downcased current class name that we use to define name for
        #   given Cli command
        # @example for Karafka::Cli::Install
        #   name #=> 'install'
        def name
          to_s.split('::').last.downcase
        end
      end
    end
  end
end
