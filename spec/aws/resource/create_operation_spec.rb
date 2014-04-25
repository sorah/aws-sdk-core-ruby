module Aws
  class Resource
    describe CreateOperation do
      describe '#request' do

        it 'returns the request given to the constructor' do
          request = double('request')
          operation = CreateOperation.new(
            request: request,
            builder: double('builder')
          )
          expect(operation.request).to be(request)
        end

        it 'requries a :request option' do
          msg = 'missing required option :request'
          expect {
            CreateOperation.new(
              request: nil,
              builder: double('builder')
            )
          }.to raise_error(Errors::DefinitionError, msg)
        end

      end

      describe '#builder' do

        it 'returns the builder given to the constructor' do
          builder = double('builder')
          operation = CreateOperation.new(
            request: double('request'),
            builder: builder
          )
          expect(operation.builder).to be(builder)
        end

        it 'requries a :builder option' do
          msg = 'missing required option :builder'
          expect {
            CreateOperation.new(
              request: double('request'),
              builder: nil,
            )
          }.to raise_error(Errors::DefinitionError, msg)
        end

      end

      context '#invoke' do

        it 'invokes the request, passing the response onto the builder' do

          client = double('client')
          response = double('client-response', data:{'path' => 'id'})
          parent = double('resource-parent', client:client)

          expect(client).to receive(:operation_name).
            with(param:'param-value').
            and_return(response)

          resource_class = Resource.define(double('client-class'), ['id'])

          request = Request.new(method_name: 'operation_name')
          builder = Builder.new(resource_class:resource_class, sources:[
            BuilderSources::ResponsePath.new('path', 'id')
          ])

          operation = CreateOperation.new(request:request, builder:builder)

          resource = operation.invoke(
            resource:parent,
            params:{param:'param-value'}
          )
          expect(resource).to be_kind_of(resource_class)
          expect(resource.identifiers).to eq(:id => 'id')
          expect(resource.client).to be(parent.client)
        end

      end
    end
  end
end
