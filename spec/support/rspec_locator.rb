# frozen_string_literal: true

%w[
  fileutils
].each(&method(:require))

# RSpec extension for the `RSpec.describe` subject class auto-discovery
# It automatically detects the class name that should be described in the given spec
# based on the spec file path.
# @example Just include it, extend with instantiation and use `RSpec#describe_current`
#   instead of `RSpec#describe`
#   RSpec.extend SupportEngine::RSpecLocator.new(__FILE__)
class RSpecLocator < Module
  # @param  spec_helper_file_path [String] path to the spec_helper.rb file
  def initialize(spec_helper_file_path)
    super()
    @specs_root_dir = ::File.dirname(spec_helper_file_path)
  end

  # Builds needed API
  # @param rspec [Module] RSpec main module
  def extended(rspec)
    super

    this = self

    # Allows "auto subject" definitions for the `#describe` method, as it will figure
    # out the proper class that we want to describe
    # @param block [Proc] block with specs
    rspec.define_singleton_method :describe_current do |&block|
      describe(this.inherited, &block)
    end
  end

  # @return [Class] class name for the RSpec `#describe` method
  def inherited
    caller(2..2)
      .first
      .split(':')
      .first
      .gsub(@specs_root_dir, '')
      .gsub('_spec.rb', '')
      .split('/')
      .delete_if(&:empty?)
      .itself[1..]
      .join('/')
      .camelize
      .constantize
  end
end
