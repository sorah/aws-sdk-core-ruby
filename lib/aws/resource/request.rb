require 'jamespath'

module Aws
  class Resource
    class Request

      include Options

      # @option opitons [requried, String] :method_name
      # @option options [Array<RequestParams::Param>] :params ([]) A list of
      #   request params to apply to the request when invoked.
      def initialize(options = {})
        @method_name = option(:method_name, options)
        @params = options[:params] || []
      end

      # @return [String] Name of the method called on the client when this
      #   operation is invoked.
      attr_reader :method_name

      # @return [Array<RequestParams::Param>]
      attr_reader :params

      # @option options [required, Resource] :resource
      # @option options [Hash] :params ({})
      # @return [Seahorse::Client::Response]
      def invoke(options = {})
        client(options).send(@method_name, build_params(options))
      end

      private

      def client(options)
        option(:resource, options).client
      end

      def build_params(options)
        @params.each.with_object(options[:params] || {}) do |param, hash|
          param.apply(hash, options)
        end
      end

    end
  end
end
