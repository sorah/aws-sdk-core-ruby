require 'jamespath'

module Aws
  class Resource

    # A {Builder} construct resource objects.  It extracts resource identifiers
    # for the objects it builds from another resource object and/or an
    # AWS response.
    class Builder

      include Options

      # @option options [required, Class<Resource>] resource_class
      # @option options [Array<BuilderSources::Source>] :sources ([])
      def initialize(options)
        @resource_class = option(:resource_class, options)
        @sources = options[:sources] || []
        if @load_path = options[:load_path]
          @sources << BuilderSources::ResponsePath.new(@load_path, :data)
        end
        @plural = @sources.any?(&:plural?)
        arguments = @resource_class.identifiers - @sources.map(&:target)
        arguments.each do |identifier|
          @sources << BuilderSources::Argument.new(identifier.to_s, identifier)
        end
      end

      # @return [Class<Resource>]
      attr_reader :resource_class

      # @return [Array<BuilderSources::Source>] A list of resource
      #   identifier sources.
      attr_reader :sources

      # @return [String<JAMESPath>, nil] A JAMESPath expression that
      #   points to the resource data for constructed objects in the
      #   response.
      attr_reader :load_path

      # @return [Boolean] Returns `true` if this builder returns an array
      #   of resource objects from #{build}.
      attr_reader :plural

      alias plural? plural

      # @return [Boolean] Returns `true` if this builder requires user
      #   input to specify an identifier
      def requires_argument?
        BuilderSources::Argument === @sources.last
      end

      # @option [Resource] :resource
      # @option [Seahorse::Client::Response] :response
      # @return [Resource, Array<Resource>] Returns a resource object or an
      #   array of resource objects if {#plural}.
      def build(options = {}, &block)
        identifier_map = @sources.each.with_object({}) do |source, hash|
          hash[source.target] = source.extract(options)
        end
        if plural?
          build_plural(identifier_map, options, &block)
        else
          build_one(identifier_map, options)
        end
      end

      private

      def build_plural(identifier_map, options, &block)
        (0...resource_count(identifier_map)).collect do |n|
          identifiers = @sources.each.with_object({}) do |source, identifiers|
            identifiers[source.target] = source.plural? ?
              identifier_map[source.target][n] :
              identifier_map[source.target]
          end
          resource = build_one(identifiers, options)
          yield(resource) if block_given?
          resource
        end
      end

      def build_one(identifiers, options)
        @resource_class.new(identifiers.merge(
          client: client(options)
        ))
      end

      def resource_count(identifier_map)
        identifier_map.values.inject(0) do |max, values|
          [max, values.is_a?(Array) ? values.size : 0].max
        end
      end

      def client(options)
        options[:resource].client
      end

      def extract_data(options)
        if @load_path == '$'
          options[:response].data
        elsif @load_path
          Jamespath.search(@load_path, options[:response].data)
        end
      end

    end
  end
end
