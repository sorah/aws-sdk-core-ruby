require 'spec_helper'

module Aws
  class Resource
    describe Definition do

      describe '#source' do

        it 'returns the given source deifinition' do
          source = {}
          definition = Definition.new(source)
          expect(definition.source).to be(source)
        end

      end

      describe '#define_service' do

        let(:client) { double('client') }

        let(:client_class) { double('client-class') }

        let(:definition) {{
          'service' => {},
          'resources' => {},
        }}

        let(:service_class) {
          Definition.new(definition).define_service('Svc', client_class)
        }

        let(:service) { service_class.new }

        before(:each) do
          allow(client_class).to receive(:new).and_return(client)
        end

        describe 'service' do

          it 'constructs default clients' do
            expect(client_class).to receive(:new).and_return(client)
            svc = Definition.new(definition).define_service('Name', client_class)
            expect(svc.client_class).to be(client_class)
            expect(svc.new.client).to be(client)
          end

          it 'defines a resource class for each named resource' do
            definition['resources'] = {
              'Group' => { 'identifiers' => %w(Id) },
              'User' => { 'identifiers' => %w(Name) }
            }

            user = service_class::User.new(name:'user-name')
            expect(user).to be_kind_of(Resource)
            expect(user.identifiers).to eq(name:'user-name')

            group = service_class::Group.new(id:'group-id')
            expect(group).to be_kind_of(Resource)
            expect(group.identifiers).to eq(id:'group-id')
          end

          describe 'actions' do

            it 'supports basic operations' do
              definition['service'] = {
                'actions' => {
                  'DoSomething' => {
                    'request' => {
                      'operation' => 'ClientMethod'
                    }
                  }
                }
              }

              expect(service).to respond_to(:do_something)

              client_response = double('client-response')
              expect(client).to receive(:client_method).
                with(foo:'bar').
                and_return(client_response)

              resp = service.do_something(foo:'bar')
              expect(resp).to be(client_response)
            end

            it 'supports operations that extract data' do
              definition['service'] = {
                'actions' => {
                  'DoSomething' => {
                    'request' => {
                      'operation' => 'ClientMethod'
                    },
                    'path' => 'Nested.Value'
                  }
                }
              }

              expect(client).to receive(:client_method).
                and_return(double('client-response',
                  data: { 'nested' => { 'value' => 'nested-value' }}
                ))

              resp = service.do_something(foo:'bar')
              expect(resp).to eq('nested-value')
            end

            it 'supports operations that return singular resources' do
              definition.update(
                'service' => {
                  'actions' => {
                    'CreateThing' => {
                      'request' => {
                        'operation' => 'MakeThing'
                      },
                      'resource' => {
                        'type' => 'Thing',
                        'identifiers' => [
                          {
                            'target' => 'Name',
                            'sourceType' => 'requestParameter',
                            'source' => 'ThingName'
                          }
                        ]
                      }
                    }
                  }
                },
                'resources' => {
                  'Thing' => {
                    'identifiers' => ['Name']
                  }
                }
              )

              expect(client).to receive(:make_thing).
                with(thing_name:'thing-name') do |params|
                  double('client-response',
                    context: double('request-context', params:params))
                end

              thing = service.create_thing(thing_name:'thing-name')
              expect(thing).to be_kind_of(service_class::Thing)
              expect(thing.client).to be(service.client)
              expect(thing.name).to eq('thing-name')
            end

            it 'accepts identifier names in place of request params' do
              pending('not implemented yet')
              definition.update(
                'service' => {
                  'actions' => {
                    'CreateThing' => {
                      'request' => {
                        'operation' => 'MakeThing'
                      },
                      'resource' => {
                        'type' => 'Thing',
                        'identifiers' => [
                          {
                            # very similar to the previous test except
                            # expect the create method to accept the option
                            # `:name => 'thing-name' instead of the default
                            # `:thing_name => 'thing-name'`
                            'target' => 'Name',
                            'sourceType' => 'requestParameter',
                            'source' => 'ThingName'
                          }
                        ]
                      }
                    }
                  }
                },
                'resources' => {
                  'Thing' => {
                    'identifiers' => ['Name']
                  }
                }
              )

              expect(client).to receive(:make_thing).
                with(thing_name:'thing-name') do |params|
                  double('client-response',
                    context: double('request-context', params:params))
                end

              thing = service.create_thing(name:'thing-name')
              expect(thing.name).to eq('thing-name')
            end

            it 'can return an array of resources' do
              definition.update(
                'service' => {
                  'actions' => {
                    'CreateThings' => {
                      'request' => {
                        'operation' => 'MakeThings'
                      },
                      'resource' => {
                        'type' => 'Thing',
                        'identifiers' => [
                          {
                            # using JMESPath to extract thing names
                            'target' => 'Name',
                            'sourceType' => 'responsePath',
                            'source' => 'Things[].Name'
                          }
                        ]
                      }
                    }
                  }
                },
                'resources' => {
                  'Thing' => {
                    'identifiers' => ['Name']
                  }
                }
              )

              client_response = double('client-response', data: {
                'things' => [
                  { 'name' => 'thing1' },
                  { 'name' => 'thing2' },
                ]
              })
              expect(client).to receive(:make_things).
                and_return(client_response)

              things = service.create_things
              expect(things).to be_an(Array)
              expect(things[0]).to be_kind_of(service_class::Thing)
              expect(things[1].client).to be(service.client)
              expect(things.map(&:name)).to eq(['thing1', 'thing2'])
            end

            it 'can return hydrated resources' do
              definition.update(
                'service' => {
                  'actions' => {
                    'CreateThings' => {
                      'request' => {
                        'operation' => 'MakeThings'
                      },
                      'resource' => {
                        'type' => 'Thing',
                        'identifiers' => [
                          {
                            # using JMESPath to extract thing names
                            'target' => 'Name',
                            'sourceType' => 'responsePath',
                            'source' => 'Things[].Name'
                          }
                        ],
                        'path' => 'Things[]'
                      }
                    }
                  }
                },
                'resources' => {
                  'Thing' => {
                    'identifiers' => ['Name']
                  }
                }
              )

              client_response = double('client-response', data: {
                'things' => [
                  { 'name' => 'thing1', 'arn' => 'thing1-arn' },
                  { 'name' => 'thing2', 'arn' => 'thing2-arn' },
                ]
              })
              expect(client).to receive(:make_things).
                and_return(client_response)

              things = service.create_things
              expect(things.map(&:data)).to eq([
                { 'name' => 'thing1', 'arn' => 'thing1-arn' },
                { 'name' => 'thing2', 'arn' => 'thing2-arn' },
              ])
            end

          end

          describe 'has many associations' do

            let(:definition) {{
              'service' => {
                'hasMany' => {
                  'Things' => {
                    'request' => { 'operation' => 'ListThings' },
                    'resource' => {
                      'type' => 'Thing',
                      'identifiers' => [
                        {
                          'target' => 'Name',
                          'sourceType' => 'responsePath',
                          'source' => 'Things[].Name'
                        }
                      ],
                      'path' => 'Things[]'
                    },
                    'singularName' => 'Thing'
                  }
                }
              },
              'resources' => {
                'Thing' => {
                  'identifiers' => ['Name']
                }
              }
            }}

            it 'returns an resource enumerator' do
              expect(client).to receive(:list_things).
                with(batch_size:2).
                and_return([
                  double('client-response-1', data: {
                    'things' => [
                      { 'name' => 'thing1', 'arn' => 'thing1-arn' },
                      { 'name' => 'thing2', 'arn' => 'thing2-arn' },
                    ]
                  }),
                  double('client-response-2', data: {
                    'things' => [
                      { 'name' => 'thing3', 'arn' => 'thing3-arn' },
                      { 'name' => 'thing4', 'arn' => 'thing4-arn' },
                    ]
                  }),
                ]
              )
              things = service.things(batch_size:2)
              expect(things).to be_an(Enumerator)
              expect(things.map(&:name)).to eq(%w(thing1 thing2 thing3 thing4))
            end

            it 'defines getter helpers for sub-resources' do
              thing = service.thing('thing-name')
              expect(thing).to be_kind_of(service_class::Thing)
              expect(thing.name).to eq('thing-name')
              expect(thing.client).to be(service.client)
            end

          end

        end

        describe 'resources' do

          describe '#load' do

            it 'raises a NotImplementedError when not specified'

            it 'loads and returns resource data'

            it 'caches resource data'

            it 'reloads data on request'

          end

          describe 'actions' do
          end

          describe 'has many associations' do

            it 'returns an Enumerator'

            it 'defines a getter for sub-resources'

            it 'does not define a getter for sibling resources'

          end

          describe 'has some associations' do

            it 'returns an array of resource objects'

          end

          describe 'has one associations' do

            it 'returns a single resource object'

          end
        end
      end
    end
  end
end
