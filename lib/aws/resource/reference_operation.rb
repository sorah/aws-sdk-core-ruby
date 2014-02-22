module Aws
  class Resource
    class ReferenceOperation

      include Options

      # @option options [required, Builder] :builder
      def initialize(options = {})
        @builder = option(:builder, options)
      end

      # @return [Builder]
      attr_reader :builder

      # @option options [required, Resource] :resource
      # @option options [required, String] :argument
      # @return [Resource]
      def invoke(options)
        @builder.build(options)
      end

    end
  end
end
