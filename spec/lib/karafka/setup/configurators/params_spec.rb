# frozen_string_literal: true

# @note We check the effects of this configurator as it is executed before we run specs
RSpec.describe Karafka::Setup::Configurators::Params do
  subject(:params_class) { Karafka::Params::Params }

  it { expect(params_class).to be < Hash }
  it { expect(params_class.included_modules.include?(Karafka::Params::Dsl)).to eq true }
end
