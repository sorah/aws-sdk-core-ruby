require 'spec_helper'

module Aws
  describe Resource do

    let(:client_class) { double('client-class') }

    let(:client) { double('client') }

    let(:resource_name) { 'Aws::Resources::Example' }

    let(:resource_class) { Resource.define(client_class) }

    let(:resource) { resource_class.new }

    before(:each) do
      allow(client_class).to receive(:new).and_return(client)
      allow(resource_class).to receive(:name).and_return(resource_name)
    end

    describe '#client' do

      it 'constructs and returns a default client object' do
        expect(client_class).to receive(:new).and_return(client)
        expect(resource_class.new.client).to be(client)
      end

      it 'accepts a client object as a constructor option' do
        my_client = double('my-client')
        resource = resource_class.new(client:my_client)
        expect(resource.client).to be(my_client)
      end

    end

    describe '#identifiers' do

      it 'requires identifiers to be given to the constructor' do
        resource_class.add_identifier(:name)
        expect {
          resource_class.new
        }.to raise_error(ArgumentError, 'missing required option :name')
      end

      it 'returns a hash of resource identifiers' do
        resource_class.add_identifier(:id1)
        resource_class.add_identifier(:id2)
        resource = resource_class.new(id1:'abc', id2:'xyz')
        expect(resource.identifiers).to eq(id1:'abc', id2:'xyz')
      end

      it 'defines a getter for each identifier' do
        resource_class.add_identifier(:name)
        resource = resource_class.new(name:'NAME')
        expect(resource.name).to eq('NAME')
      end

    end

    describe '#inspect' do

      it 'contains the resource class name' do
        expect(resource.inspect).to eq('#<Aws::Resources::Example>')
      end

      it 'includes identifiers in the inspect string' do
        resource_class.add_identifier(:name)
        resource = resource_class.new(name:'abc')
        expect(resource.inspect).to eq('#<Aws::Resources::Example name="abc">')
      end

    end

    describe 'data methods' do

      let(:resource) { resource_class.new }

      let(:data) { double('data') }

      let(:data2) { double('data-2') }

      let(:datas) { [data, data2] }

      let(:load_operation) { double('load-operation') }

      before(:each) do
        allow(load_operation).to receive(:invoke).with(resource:resource) do |opts|
          opts[:resource].data = datas.shift
        end
        resource_class.load_operation = load_operation
      end

      describe '#data' do

        it 'raises a NotImplementedError when load_operation is not defined' do
          resource_class.load_operation = nil
          msg = "load not defined for #{resource_name}"
          expect {
            resource_class.new.load
          }.to raise_error(NotImplementedError, msg)
        end

        it 'returns data cached by the load operation' do
          expect(resource.data).to be(data)
        end

        it 'returns cached data' do
          expect(load_operation).to receive(:invoke).exactly(1).times
          expect(resource.data).to be(data)
          expect(resource.data).to be(data)
        end

      end

      describe '#load' do

        it 'forces loading data' do
          expect(load_operation).to receive(:invoke).exactly(2).times
          resource.load
          resource.load
        end

        it 'updates the cached data' do
          expect(resource.load.data).to be(data)
          expect(resource.load.data).to be(data2)
          expect(resource.data).to be(data2)
        end

        it 'is aliased as #reload' do
          expect(resource.reload.data).to be(data)
          expect(resource.reload.data).to be(data2)
        end

      end

      describe '#data_loaded?' do

        it 'returns false if data is not loaded' do
          expect(resource.data_loaded?).to be(false)
        end

        it 'returns true if data is loaded' do
          resource.load
          expect(resource.data_loaded?).to be(true)
        end

      end

    end

    describe 'class methods' do

      describe '.define' do

        it 'returns a subclass of Resource' do
          resource_class = Resource.define(double('client-class'))
          expect(resource_class.ancestors).to include(Resource)
        end

        it 'populates the default client class' do
          client_class = double('client-class')
          resource_class = Resource.define(client_class)
          expect(resource_class.client_class).to be(client_class)
        end

      end

      describe 'identifiers' do

        it 'returns an array of identifier names' do
          resource_class.add_identifier(:id1)
          resource_class.add_identifier('id2')
          expect(resource_class.identifiers).to eq([:id1, :id2])
        end

      end

      describe 'operation methods' do

        let(:operation) { double('operation') }

        let(:response) { double('operation-response') }

        describe 'add_operation' do

          it 'defines a method that invokes the operation' do
            resource_class.add_operation(:action, operation)
            expect(operation).to receive(:invoke).
              with(hash_including(resource:resource)).
              and_return(response)
            expect(resource.action).to be(response)
          end

          it 'passes additional arguments to the operation' do
            resource_class.add_operation(:action, operation)
            expect(operation).to receive(:invoke).
              with(resource:resource, params:{foo:'bar'}).
              and_return(response)
            resource.action(foo:'bar')
          end

          it 'defines a helper requiring an identifer for ReferenceOperations' do
            builder = double('resource-builder', :requires_argument? => true)
            operation = Resource::ReferenceOperation.new(builder: builder)
            resource_class.add_operation(:reference, operation)
            expect(resource.method(:reference).arity).to be(1)
          end

          it 'defines a helper requiring an identifer for ReferenceOperations' do
            builder = double('resource-builder', :requires_argument? => false)
            operation = Resource::ReferenceOperation.new(builder: builder)
            resource_class.add_operation(:reference, operation)
            expect(resource.method(:reference).arity).to be(0)
          end

        end

        describe 'operation_names' do

          it 'returns a list of operation names' do
            resource_class.add_operation(:action1, double('operation1'))
            resource_class.add_operation('action2', double('operation2'))
            expect(resource_class.operation_names).to eq([:action1, :action2])
          end

        end

        describe 'operation' do

          it 'returns the named operation' do
            resource_class.add_operation(:name, operation)
            expect(resource_class.operation(:name)).to be(operation)
          end

          it 'raises an error for unknown operations' do
            msg = "operation `unknown' not defined"
            expect {
              resource_class.operation(:unknown)
            }.to raise_error(Resource::Errors::UnknownOperationError, msg)
          end

        end

        describe 'operations' do

          it 'returns an enumerable' do
            expect(resource_class.operations).to be_kind_of(Enumerable)
          end

          it 'enumerates resource operations' do
            operation1 = double('operation-1')
            operation2 = double('operation-2')
            resource_class.add_operation(:action1, operation1)
            resource_class.add_operation(:action2, operation2)
            yielded = []
            resource_class.operations.each do |name, operation|
              yielded << [name, operation]
            end
            expect(yielded).to eq([[:action1, operation1], [:action2, operation2]])
          end

        end
      end
    end
  end
end
