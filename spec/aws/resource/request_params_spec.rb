require 'spec_helper'

module Aws
  class Resource
    describe RequestParams do

      describe RequestParams::Base do

        it 'supports simple param targets' do
          param = RequestParams::Base.new('param_name')
          params = param.apply({}, 'value')
          expect(params).to eq(param_name:'value')
        end

        it 'supports nested param targets' do
          params = {}
          RequestParams::Base.new('person.name').apply(params, 'John Doe')
          RequestParams::Base.new('person.age').apply(params, 40)
          expect(params).to eq(person: { name:'John Doe', age: 40})
        end

        it 'supports list param targets' do
          params = {}
          RequestParams::Base.new('params[]').apply(params, 'p1')
          RequestParams::Base.new('params[]').apply(params, 'p2')
          expect(params).to eq(params:['p1','p2'])
        end

        it 'supports numbered list members' do
          params = {}
          RequestParams::Base.new('people[0].name').apply(params, 'name1')
          RequestParams::Base.new('people[0].age').apply(params, 30)
          RequestParams::Base.new('people[1].name').apply(params, 'name2')
          RequestParams::Base.new('people[1].age').apply(params, 40)
          expect(params).to eq(people:[{name:'name1',age:30},{name:'name2',age:40}])
        end

        it 'supports nested lists' do
          params = {}
          RequestParams::Base.new('params[0].name').apply(params, 'n1')
          RequestParams::Base.new('params[0].values[]').apply(params, 'v1')
          RequestParams::Base.new('params[0].values[]').apply(params, 'v2')
          RequestParams::Base.new('params[1].name').apply(params, 'n2')
          RequestParams::Base.new('params[1].values[]').apply(params, 'v3')
          RequestParams::Base.new('params[1].values[]').apply(params, 'v4')
          expect(params).to eq(params:[{name:'n1', values:['v1','v2']},{name:'n2', values:['v3','v4']}])
        end

      end

      describe RequestParams::Identifier do

        it 'is a subclass of Base' do
          expect(RequestParams::Identifier.ancestors).to include(
            RequestParams::Base)
        end

        it 'extracts the identifier from the given resource' do
          resource = double('resource', identifiers: { id: 'abcmnoxyz' })
          param = RequestParams::Identifier.new('id', :name)
          expect(param.apply({}, resource:resource)).to eq(name:'abcmnoxyz')
        end

      end

      describe RequestParams::DataMember do

        it 'is a subclass of Base' do
          expect(RequestParams::DataMember.ancestors).to include(
            RequestParams::Base)
        end

        it 'extracts the data member value from the given resoruce' do
          resource = double('resource', data: { member_name: 'johndoe' })
          param = RequestParams::DataMember.new('member_name', :name)
          expect(param.apply({}, resource:resource)).to eq(name:'johndoe')
        end

      end

      describe RequestParams::String do

        it 'is a subclass of Base' do
          expect(RequestParams::String.ancestors).to include(
            RequestParams::Base)
        end

        it 'applies the source as a string literal' do
          param = RequestParams::String.new('abc', :value)
          expect(param.apply({})).to eq(value:'abc')
        end

      end

      describe RequestParams::Integer do

        it 'is a subclass of Base' do
          expect(RequestParams::Integer.ancestors).to include(
            RequestParams::Base)
        end

        it 'applies the source as an integer' do
          param = RequestParams::Integer.new("10", :count)
          expect(param.apply({})).to eq(count:10)
        end

      end
    end
  end
end
