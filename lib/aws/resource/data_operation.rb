require 'jamespath'

module Aws
  class Resource
    class DataOperation

      include Options

      # @option options [required, Request] :request
      # @option options [required, String<JMESPath>] :path
      def initialize(options = {})
        @request = option(:request, options)
        @path = option(:path, options)
      end

      # @return [Request]
      attr_reader :request

      # @return [String<JMESPath>]
      attr_reader :path

      # @option options [Resource] :resource
      # @option options [Hash] :params ({})
      # @return [Resource] Returns the given `resource`.
      def invoke(options)
        extract(@request.invoke(options))
      end

      private

      def extract(resp)
        @path == '$' ? resp.data : Jamespath.search(@path, resp.data)
      end

    end
  end
end
