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

      describe '#apply' do

        let(:client) { double('client') }

        let(:client_class) { double('client-class') }

        let(:namespace) { Resource.define(client_class) }

        let(:svc) { namespace.new }

        before(:each) do
          allow(client_class).to receive(:new).and_return(client)
        end

        describe 'resource classes' do

          it 'defines one resource class for each resource entry' do
            Definition.new(
              'resources' => {
                'User' => { 'identifiers' => %w(Name) },
                'Group' => { 'identifiers' => %w(Id) }
              }
            ).apply(namespace)
            user = namespace::User.new(name:'user-name')
            group = namespace::Group.new(id:'group-id')
            expect(user).to be_kind_of(Resource)
            expect(user.identifiers).to eq(name:'user-name')
            expect(group).to be_kind_of(Resource)
            expect(group.identifiers).to eq(id:'group-id')
          end

        end

        describe 'getter methods' do

          it 'adds a getter method to construct resource objects' do
            Definition.new(
              'resources' => {
                'User' => { 'identifiers' => %w(Name) },
              }
            ).apply(namespace)
            user = namespace.new.user('user-name')
            expect(user).to be_kind_of(namespace::User)
            expect(user.identifiers).to eq(name:'user-name')
          end

          it 'injects the client into the new resource' do
            Definition.new(
              'resources' => {
                'User' => { 'identifiers' => %w(Name) },
              }
            ).apply(namespace)
            client = double('client')
            svc = namespace.new(client:client)
            expect(svc.user('user-name').client).to be(client)
          end

          it 'define getters for resources with less than 2 identifier' do
            Definition.new(
              'resources' => {
                'Group' => { 'identifiers' => %w(Id1) },
                'User' => { 'identifiers' => %w(Id1 Id2) },
                'Other' => { 'identifiers' => [] }
              }
            ).apply(namespace)
            expect(namespace.new).to respond_to(:group)
            expect(namespace.new).not_to respond_to(:user)
            expect(namespace.new).to respond_to(:other)
            expect(namespace.new.other.identifiers).to eq({})
          end

        end

        describe 'load operation' do

          it 'adds the ability to load resource data from a client request' do
            Definition.new(
              'resources' => {
                'User' => {
                  'identifiers' => ['Name'],
                  'load' => {
                    'request' => {
                      'operation' => 'OperationName',
                      'params' => [
                        {
                          'target' => 'User.Name',
                          'sourceType' => 'identifier',
                          'source' => 'Name'
                        }
                      ]
                    },
                    'shapePath' => 'User.Details'
                  }
                }
              }
            ).apply(namespace)

            data = { 'user' => { 'details' => { arn:'user-arn' }}}
            expect(client).to receive(:operation_name).
              with(user:{name:'johndoe'}).
              and_return(double('response', data:data))

            user = namespace::User.new(name:'johndoe')
            expect(user.load.data).to eq(arn:'user-arn')
          end

          it 'raises an error if load is called but not defined' do
            Definition.new(
              'resources' => { 'User' => { 'identifiers' => ['Name'] } }
            ).apply(namespace)
            user = namespace::User.new(name:'johndoe')
            expect {
              user.load
            }.to raise_error(NotImplementedError, /load not defined for/)
          end

        end

        describe 'create operation' do

          let(:params) {{ user_name:'johndoe' }}

          let(:definition) {{
            'resources' => {
              'User' => {
                'identifiers' => ['Name'],
                'create' => {
                  'request' => { 'operation' => 'CreateUser' },
                  'resource' => {
                    'identifiers' => [
                      {
                        'target' => 'Name',
                        'sourceType' => 'requestParameter',
                        'source' => 'UserName'
                      }
                    ]
                  }
                }
              }
            }
          }}

          let(:data) { double('data') }

          let(:response) {
            double('client-response',
              context: double('request-context', params:params),
              data: { 'user' => data})
          }

          before(:each) do
            expect(client).to receive(:create_user).
              with(params).
              and_return(response)
          end

          it 'adds a helper method that creates and returns resource' do
            Definition.new(definition).apply(namespace)
            user = namespace.new.create_user(user_name:'johndoe')
            expect(user).to be_kind_of(namespace::User)
            expect(user.name).to eq('johndoe')
            expect(user.client).to be(namespace.new.client)
          end

          it 'populates the resource data if shapePath is provided' do
            definition['resources']['User']['create']['resource']['shapePath'] = 'User'
            Definition.new(definition).apply(namespace)
            user = namespace.new.create_user(user_name:'johndoe')
            expect(user.data).to be(data)
          end

        end

        describe 'enumerate operation' do

          let(:definition) {{
            'resources' => {
              'User' => {
                'identifiers' => ['Name'],
                'enumerate' => {
                  'request' => { 'operation' => 'ListUsers' },
                  'resource' => {
                    'identifiers' => [
                      {
                        'target' => 'Name',
                        'sourceType' => 'responsePath',
                        'source' => 'Users[].Name'
                      }
                    ]
                  }
                }
              }
            }
          }}

          let(:resp1) {
            double('client-response-1', data: { 'users' => [
              { 'name' => 'user-1' },
              { 'name' => 'user-2' }
            ]})
          }

          let(:resp2) {
            double('client-response-2', data: { 'users' => [
              { 'name' => 'user-3' },
              { 'name' => 'user-4' }
            ]})
          }

          before(:each) do
            allow(client).to receive(:list_users).and_return([resp1, resp2])
          end

          it 'adds a helper method that returns a resource enumerator' do
            Definition.new(definition).apply(namespace)
            users = namespace.new.users
            expect(users).to be_kind_of(Enumerable)
            expect(users.map(&:name)).to eq(%w(user-1 user-2 user-3 user-4))
            users.each do |user|
              expect(user).to be_kind_of(namespace::User)
              expect(user.client).to be(namespace.new.client)
            end
          end

        end

        describe 'actions' do

          it 'describes resource instance operation methods' do
            Definition.new(
              'resources' => {
                'User' => {
                  'identifiers' => ['Name'],
                  'actions' => {
                    'Delete' => {
                      'request' => {
                        'operation' => 'DeleteUser',
                        'params' => [
                          {
                            'target' => 'UserName',
                            'sourceType' => 'identifier',
                            'source' => 'Name'
                          }
                        ]
                      }
                    }
                  }
                }
              }
            ).apply(namespace)

            client_response = double('client-response')

            expect(client).to receive(:delete_user).
              with(user_name:'johndoe').
              and_return(client_response)

            user = namespace.new.user('johndoe')
            resp = user.delete
            expect(resp).to be(client_response)
          end

          it 'deep merges incoming params' do
            Definition.new(
              'resources' => {
                'BucketVersioning' => {
                  'identifiers' => ['BucketName'],
                  'actions' => {
                    'Enable' => {
                      'request' => {
                        'operation' => 'PutBucketVersioning',
                        'params' => [
                          { 'target' => 'Bucket', 'sourceType' => 'identifier', 'source' => 'BucketName' },
                          { 'target' => 'VersioningConfiguration.Status', 'sourceType' => 'string', 'source' => 'Enabled' }
                        ]
                      }
                    }
                  }
                }
              }
            ).apply(namespace)

            expect(client).to receive(:put_bucket_versioning).with(
              bucket:'aws-sdk',
              versioning_configuration: {
                status: 'Enabled',
                mfa_delete: 'Enabled',
              })

            versioning = namespace::BucketVersioning.new(bucket_name:'aws-sdk')
            versioning.enable(versioning_configuration:{mfa_delete:'Enabled'})
          end

          # TODO : determine how to specify the resource class to construct
          it 'supports create actions that return a resource object'

        end

        describe 'associations' do

          describe 'has many' do

            describe 'create' do

              it 'defines a helper that creates and returns the associated resource' do
                Definition.new(
                  'resources' => {
                    'User' => {
                      'identifiers' => ['Name'],
                      'associations' => {
                        'Permissions' => {
                          'hasMany' => 'Permission',
                          'create' => {
                            'request' => {
                              'operation' => 'AddPermissionToUser',
                              'params' => [
                                {
                                  'target' => 'UserName',
                                  'sourceType' => 'identifier',
                                  'source' => 'Name'
                                }
                              ]
                            },
                            'resource' => {
                              'identifiers' => [
                                {
                                  'target' => 'Id',
                                  'sourceType' => 'responsePath',
                                  'source' => 'Permission.Id'
                                }
                              ]
                            }
                          }
                        }
                      }
                    },
                    'Permission' => { 'identifiers' => ['Id'] }
                  }
                ).apply(namespace)


                client_response = double('client-response', data: { 'permission' => { 'id' => 'pid' }})
                expect(client).to receive(:add_permission_to_user).
                  with(user_name:'johndoe', foo:'bar').
                  and_return(client_response)

                user = namespace.new.user('johndoe')
                permission = user.create_permission(foo:'bar')
                expect(permission).to be_kind_of(namespace::Permission)
                expect(permission.id).to eq('pid')
                expect(permission.client).to be(user.client)
              end

            end

            describe 'enumerate' do

              it 'defines a helper that enumerates the associated resource' do
                Definition.new(
                  'resources' => {
                    'User' => {
                      'identifiers' => ['Name'],
                      'associations' => {
                        'Permissions' => {
                          'hasMany' => 'Permission',
                          'enumerate' => {
                            'request' => {
                              'operation' => 'GetUserPermissions',
                              'params' => [
                                {
                                  'target' => 'UserName',
                                  'sourceType' => 'identifier',
                                  'source' => 'Name'
                                }
                              ]
                            },
                            'resource' => {
                              'identifiers' => [
                                {
                                  'target' => 'Id',
                                  'sourceType' => 'responsePath',
                                  'source' => 'Permissions[].Id'
                                }
                              ]
                            }
                          }
                        }
                      }
                    },
                    'Permission' => { 'identifiers' => ['Id'] }
                  }
                ).apply(namespace)

                resp1 = double('resp-1', data: { 'permissions' => [{ 'id' => 'pid-1' }]})
                resp2 = double('resp-2', data: { 'permissions' => [{ 'id' => 'pid-2' }]})

                allow(client).to receive(:get_user_permissions).
                  with(user_name:'johndoe', batch_size:1).
                  and_return([resp1, resp2])

                user = namespace.new.user('johndoe')
                permissions = user.permissions(batch_size:1)
                expect(permissions).to be_kind_of(Enumerable)
                expect(permissions.map(&:id)).to eq(%w(pid-1 pid-2))
                permissions.each do |permission|
                  expect(permission).to be_kind_of(namespace::Permission)
                  expect(permission.client).to be(user.client)
                end
              end

            end

            describe 'reference' do

              it 'defines a helper that constructs the resource' do
                Definition.new(
                  'resources' => {
                    'Bucket' => {
                      'identifiers' => ['Name'],
                      'associations' => {
                        'Objects' => {
                          'hasMany' => 'Object',
                          'resource' => {
                            'identifiers' => [
                              {
                                'target' => 'BucketName',
                                'sourceType' => 'identifier',
                                'source' => 'Name'
                              }
                            ]
                          }
                        }
                      }
                    },
                    'Object' => { 'identifiers' => ['BucketName', 'Key'] }
                  }
                ).apply(namespace)
                bucket = namespace.new.bucket('aws-sdk')
                object = bucket.object('key')
                expect(object).to be_kind_of(namespace::Object)
                expect(object.client).to be(bucket.client)
                expect(object.key).to eq('key')
              end

            end

          end

          describe 'has' do

            it 'defines a getter method' do
              Definition.new(
                'resources' => {
                  'Bucket' => { 'identifiers' => ['Name'] },
                  'Object' => {
                    'identifiers' => ['BucketName', 'Key'],
                    'associations' => {
                      'Bucket' => {
                        'has' => 'Bucket',
                        'resource' => {
                          'identifiers' => [
                            {
                              'target' => 'Name',
                              'sourceType' => 'identifier',
                              'source' => 'BucketName'
                            }
                          ]
                        }
                      }
                    }
                  }
                }
              ).apply(namespace)
              object = namespace::Object.new(bucket_name:'aws-sdk', key:'key')
              bucket = object.bucket
              expect(bucket).to be_kind_of(namespace::Bucket)
              expect(bucket.name).to eq('aws-sdk')
              expect(bucket.client).to be(object.client)
            end

            it 'strips parent resource names from the getter name' do
              Definition.new(
                'resources' => {
                  'Bucket' => {
                    'identifiers' => ['Name'],
                    'associations' => {
                      'Acl' => {
                        'has' => 'BucketAcl',
                        'resource' => {
                          'identifiers' => [
                            {
                              'target' => 'BucketName',
                              'sourceType' => 'identifier',
                              'source' => 'Name'
                            }
                          ]
                        }
                      }
                    }
                  },
                  'BucketAcl' => { 'identifiers' => ['BucketName'] }
                }
              ).apply(namespace)
              bucket = namespace.new.bucket('aws-sdk')
              expect(bucket).to respond_to(:acl)
              expect(bucket).not_to respond_to(:bucket_acl)
              expect(bucket.acl).to be_kind_of(namespace::BucketAcl)
              expect(bucket.acl.client).to be(bucket.client)
            end

            it 'caches the referenced resource object' do
              Definition.new(
                'resources' => {
                  'Bucket' => {
                    'identifiers' => ['Name'],
                    'associations' => {
                      'Acl' => {
                        'has' => 'BucketAcl',
                        'resource' => {
                          'identifiers' => [
                            {
                              'target' => 'BucketName',
                              'sourceType' => 'identifier',
                              'source' => 'Name'
                            }
                          ]
                        }
                      }
                    }
                  },
                  'BucketAcl' => { 'identifiers' => ['BucketName'] }
                }
              ).apply(namespace)
              bucket = namespace.new.bucket('aws-sdk')
              expect(bucket.acl).to be(bucket.acl)
            end

          end
        end
      end
    end
  end
end
