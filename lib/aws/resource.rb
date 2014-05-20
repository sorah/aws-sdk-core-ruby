require 'aws/resource/base'
require 'aws/resource/builder'
require 'aws/resource/builder_sources'
require 'aws/resource/definition'
require 'aws/resource/definition_validator'
require 'aws/resource/errors'
require 'aws/resource/operations'
require 'aws/resource/request'
require 'aws/resource/request_params'

module Aws
  module Resource

    # @see Base.define
    # @api private
    def self.define(*args)
      Base.define(*args)
    end

  end
end
