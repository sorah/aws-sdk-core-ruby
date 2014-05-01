require 'multi_json'
require 'thread'

module Aws
  module Resources

    @define_service_mutex = Mutex.new

    # @api private
    DEFINITION_PATHS = {
      EC2: 'apis/source/ec2-2014-02-01.resources.json',
      Glacier: 'apis/source/glacier-2012-06-01.resources.json',
      IAM: 'apis/source/iam-2010-05-08.resources.json',
      S3:  'apis/source/s3-2006-03-01.resources.json',
      SNS: 'apis/source/sns-2010-03-31.resources.json',
      SQS: 'apis/source/sqs-2012-11-05.resources.json',
    }
    private_constant :DEFINITION_PATHS

    class << self

      # @api private
      def const_missing(const_name)
        if definition_path = DEFINITION_PATHS[const_name]
          define_service_resource(const_name, definition(definition_path))
        else
          raise NameError, "uninitialized constant Aws::Resources::#{const_name}"
        end
      end

      # @api private
      def constants
        (super + DEFINITION_PATHS.keys).uniq.sort
      end

      private

      # Reads a resource definition JSON document from disk, returning
      # a {Resource::Definition} object.
      # @param [String] definition_path
      # @return [Resource::Definition]
      def definition(definition_path)
        Resource::Definition.new(MultiJson.load(File.read(definition_path)))
      end

      # Constructs a resource definition for a service and all of its
      # sub resources from a {Resource::Definition}.
      # @param [Symbol] svc_name
      # @param [Resource::Definition] definition
      # @return [Class<Resource>]
      def define_service_resource(svc_name, definition)
        @define_service_mutex.synchronize do
          if const_defined?(svc_name)
            const_get(svc_name)
          else
            const_set(svc_name, build_service_resource(svc_name, definition))
          end
        end
      end

      # @param [Symbol] svc_name
      # @param [Resource::Definition] definition
      # @return [Class<Resource>]
      def build_service_resource(svc_name, definition)
        client_class = Aws.const_get(svc_name).default_client_class
        definition.define_service(svc_name, client_class)
      end

    end
  end
end
