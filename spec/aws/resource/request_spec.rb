require 'spec_helper'

module Aws
  module Resource
    describe Request do

      describe '#method_name' do

        it 'accepts a method name' do
          expect(Request.new(method_name:'foo').method_name).to eq('foo')
        end

        it 'requires a method name' do
          msg = 'missing required option :method_name'
          expect {
            Request.new
          }.to raise_error(Errors::DefinitionError, msg)
        end

      end

      describe '#params' do

        it 'defaults to an empty array' do
          expect(Request.new(method_name:'method').params).to eq([])
        end

        it 'returns the params given to the constructor' do
          params = double('param-list')
          request = Request.new(method_name:'method', params:params)
          expect(request.params).to be(params)
        end

      end

      describe '#invoke' do

        let(:client) { double('resource-client') }

        let(:resource) { double('resource', client:client) }

        let(:params) { [] }

        let(:request) { Request.new(method_name:'method_name', params:params) }

        it 'requires a :resource option' do
          msg = 'missing required option :resource'
          expect {
            request.invoke
          }.to raise_error(Errors::DefinitionError, msg)
        end

        it 'invokes the method name on the given resource client' do
          expect(client).to receive(:method_name)
          request.invoke(resource:resource)
        end

        it 'passes along params to the resource client' do
          params = { foo: 'bar' }
          expect(client).to receive(:method_name).with(params)
          request.invoke(resource:resource, params:params)
        end

        it 'returns the client response' do
          response = double('client-response')
          allow(client).to receive(:method_name).and_return(response)
          expect(request.invoke(resource:resource)).to be(response)
        end

        it 'merges request params with given params before invoke client method' do
          request = Request.new(method_name:'method_name', params: [
            RequestParams::String.new('John Doe', 'person.name'),
            RequestParams::Integer.new('40', 'person.age'),
          ])
          expect(client).to receive(:method_name).
            with(person:{name:'John Doe', age:40, aka:'johndoe'})
          request.invoke(resource:resource, params:{ person: { aka:'johndoe' }})
        end

      end
    end
  end
end
