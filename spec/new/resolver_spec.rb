describe GraphQLIncludable::New::Resolver do
  before(:each) { DatabaseCleaner.start }
  after(:each) { DatabaseCleaner.clean }

  let!(:user_1) { User.create!(name: 'Jordan', email: 'jordan@example.com') }
  let!(:location_1) { Location.create!(name: 'Office A') }
  let!(:location_2) { Location.create!(name: 'Office B') }

  let!(:task_1) { Task.create!(name: 'Task A', location: location_1) }
  let!(:task_2) { Task.create!(name: 'Task B',  location: location_1) }
  let!(:task_3) { Task.create!(name: 'Task C',  location: location_2) }

  let!(:client_1) { Client.create!(name: '1', user: user_1, tasks: [task_1, task_2]) }
  let!(:client_2) { Client.create!(name: '2', user: user_1, tasks: [task_3]) }
  let!(:client_3) { Client.create!(name: '3', user: user_1) }

  context 'with a basic schema query' do
    let(:query_string) do
      <<-GQL
      query BasicQuery {
        users {
          name
          email
          clients {
            nodes {
              name
            }
          }
        }
        clients {
          name
          user {
            name
          }
          tasks {
            edges {
              completed
              node {
                name
              }
            }
          }
        }
      }
      GQL
    end

    it 'returns the correct result' do
      result = GraphQLSchema.execute(
        query_string,
        variables: {},
        context: {}
      ).to_h

      expect(result).to eq(
        'data' => {
          'users' => [
            {
              'name' => 'Jordan',
              'email' => 'jordan@example.com',
              'clients' => {
                'nodes' => [
                  {
                    'name' => '1'
                  },
                  {
                    'name' => '2'
                  },
                  {
                    'name' => '3'
                  }
                ]
              }
            }
          ],
          'clients' => [
            {
              'name' => '1',
              'user' => { 'name' => 'Jordan' },
              'tasks' => {
                'edges' => [
                  { 'completed' => false, 'node' => { 'name' => 'Task A' } },
                  { 'completed' => false, 'node' => { 'name' => 'Task B' } }
                ]
              }
            },
            {
              'name' => '2',
              'user' => { 'name' => 'Jordan' },
              'tasks' => {
                'edges' => [
                  { 'completed' => false, 'node' => { 'name' => 'Task C' } }
                ]
              }
            },
            {
              'name' => '3',
              'user' => { 'name' => 'Jordan' },
              'tasks' => { 'edges' => [] }
            }
          ]
        }
      )
    end

    it 'generates the correct includes pattern' do
      expect do
        GraphQLSchema.execute(query_string, variables: {}, context: {})
      end.to instrument('graphql_includable.includes').with(
        operation_name: 'BasicQuery',
        field_name: 'clients',
        includes: [:user, { client_tasks: [:task] }]
      )
    end
  end

  context 'detecting under/overfetching and N+1 queries' do
    context 'for a simple edges->node query ' do
      let(:query_string) do
        <<-GQL
        query {
          clients {
            name
            user {
              name
            }
            tasks {
              edges {
                completed
                node {
                  name
                  location {
                    name
                  }
                }
              }
            }
          }
        }
        GQL
      end

      it 'generates the correct includes pattern' do
        expect do
          GraphQLSchema.execute(query_string, variables: {}, context: {})
        end.to instrument('graphql_includable.includes').with(
          operation_name: nil,
          field_name: 'clients',
          includes: [:user, { client_tasks: { task: [:location] } }]
        )
      end

      it 'does not over/under include' do
        Bullet.start_request
        result = GraphQLSchema.execute(
          query_string,
          variables: {},
          context: {}
        ).to_h
        expect(result['errors']).to be_nil
        Bullet.perform_out_of_channel_notifications if Bullet.notification?
        Bullet.end_request
      end
    end

    context 'for a simple nodes only query' do
      let(:query_string) do
        <<-GQL
        query {
          clients {
            tasks {
              nodes {
                name
                location {
                  name
                }
              }
            }
          }
        }
        GQL
      end

      it 'generates the correct includes pattern' do
        expect do
          GraphQLSchema.execute(query_string, variables: {}, context: {})
        end.to instrument('graphql_includable.includes').with(
          operation_name: nil,
          field_name: 'clients',
          includes: { tasks: [:location] }
        )
      end

      it 'does not over/under include' do
        Bullet.start_request
        result = GraphQLSchema.execute(
          query_string,
          variables: {},
          context: {}
        ).to_h
        expect(result['errors']).to be_nil
        Bullet.perform_out_of_channel_notifications if Bullet.notification?
        Bullet.end_request
      end
    end

    context 'for a simple edges only query' do
      let(:query_string) do
        <<-GQL
        query {
          clients {
            tasks {
              edges {
                completed
              }
            }
          }
        }
        GQL
      end

      it 'generates the correct includes pattern' do
        expect do
          GraphQLSchema.execute(query_string, variables: {}, context: {})
        end.to instrument('graphql_includable.includes').with(
          operation_name: nil,
          field_name: 'clients',
          includes: [:client_tasks]
        )
      end

      it 'does not over/under include' do
        Bullet.start_request
        result = GraphQLSchema.execute(
          query_string,
          variables: {},
          context: {}
        ).to_h
        expect(result['errors']).to be_nil
        Bullet.perform_out_of_channel_notifications if Bullet.notification?
        Bullet.end_request
      end
    end

    context 'for a simple edges then nodes query' do
      let(:query_string) do
        <<-GQL
        query {
          clients {
            tasks {
              edges {
                completed
              }
              nodes {
                name
                location {
                  name
                }
              }
            }
          }
        }
        GQL
      end

      it 'generates the correct includes pattern' do
        expect do
          GraphQLSchema.execute(query_string, variables: {}, context: {})
        end.to instrument('graphql_includable.includes').with(
          operation_name: nil,
          field_name: 'clients',
          includes: [:client_tasks, { tasks: [:location] }]
        )
      end

      it 'does not over/under include' do
        Bullet.start_request
        result = GraphQLSchema.execute(
          query_string,
          variables: {},
          context: {}
        ).to_h
        expect(result['errors']).to be_nil
        Bullet.perform_out_of_channel_notifications if Bullet.notification?
        Bullet.end_request
      end
    end

    context 'for a simple nodes then edges query' do
      let(:query_string) do
        <<-GQL
        query {
          clients {
            tasks {
              nodes {
                name
                location {
                  name
                }
              }
              edges {
                completed
              }
            }
          }
        }
        GQL
      end

      it 'generates the correct includes pattern' do
        expect do
          GraphQLSchema.execute(query_string, variables: {}, context: {})
        end.to instrument('graphql_includable.includes').with(
          operation_name: nil,
          field_name: 'clients',
          includes: [:client_tasks, { tasks: [:location] }]
        )
      end

      it 'does not over/under include' do
        Bullet.start_request
        result = GraphQLSchema.execute(
          query_string,
          variables: {},
          context: {}
        ).to_h
        expect(result['errors']).to be_nil
        Bullet.perform_out_of_channel_notifications if Bullet.notification?
        Bullet.end_request
      end
    end

    context 'for a query with a connection that internally queries' do
      context 'with edges' do
        let(:query_string) do
          <<-GQL
          query {
            clients {
              nested_query {
                edges {
                  completed
                }
              }
            }
          }
          GQL
        end

        it 'generates the correct includes pattern' do
          received_events = []
          subscription = ActiveSupport::Notifications.subscribe('graphql_includable.includes') do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            received_events << event
          end

          GraphQLSchema.execute(query_string, variables: {}, context: {})
          ActiveSupport::Notifications.unsubscribe(subscription)

          expect(received_events.length).to eq(4)
          clients_call = received_events[0]
          client_1_call = received_events[1]
          client_2_call = received_events[2]
          client_3_call = received_events[3]

          expect(clients_call.payload[:includes]).to eq({})
          expect(client_1_call.payload[:includes]).to eq({})
          expect(client_2_call.payload[:includes]).to eq({})
          expect(client_3_call.payload[:includes]).to eq({})
        end

        it 'does not over/under include' do
          Bullet.start_request
          result = GraphQLSchema.execute(
            query_string,
            variables: {},
            context: {}
          ).to_h
          expect(result['errors']).to be_nil
          Bullet.perform_out_of_channel_notifications if Bullet.notification?
          Bullet.end_request
        end
      end

      context 'with edges and node' do
        let(:query_string) do
          <<-GQL
          query {
            clients {
              nested_query {
                edges {
                  completed
                  node {
                    name
                    location {
                      name
                    }
                  }
                }
              }
            }
          }
          GQL
        end

        it 'generates the correct includes pattern' do
          received_events = []
          subscription = ActiveSupport::Notifications.subscribe('graphql_includable.includes') do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            received_events << event
          end

          GraphQLSchema.execute(query_string, variables: {}, context: {})
          ActiveSupport::Notifications.unsubscribe(subscription)

          expect(received_events.length).to eq(4)
          clients_call = received_events[0]
          client_1_call = received_events[1]
          client_2_call = received_events[2]
          client_3_call = received_events[3]

          expect(clients_call.payload[:includes]).to eq({})
          expect(client_1_call.payload[:includes]).to eq(task: [:location])
          expect(client_2_call.payload[:includes]).to eq(task: [:location])
          expect(client_3_call.payload[:includes]).to eq(task: [:location])
        end

        it 'does not over/under include' do
          Bullet.start_request
          result = GraphQLSchema.execute(
            query_string,
            variables: {},
            context: {}
          ).to_h
          expect(result['errors']).to be_nil
          Bullet.perform_out_of_channel_notifications if Bullet.notification?
          Bullet.end_request
        end
      end

      context 'with nodes' do
        let(:query_string) do
          <<-GQL
          query {
            clients {
              nested_query {
                nodes {
                  name
                  location {
                    name
                  }
                }
              }
            }
          }
          GQL
        end

        it 'generates the correct includes pattern' do
          received_events = []
          subscription = ActiveSupport::Notifications.subscribe('graphql_includable.includes') do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            received_events << event
          end

          GraphQLSchema.execute(query_string, variables: {}, context: {})
          ActiveSupport::Notifications.unsubscribe(subscription)

          expect(received_events.length).to eq(4)
          clients_call = received_events[0]
          client_1_call = received_events[1]
          client_2_call = received_events[2]
          client_3_call = received_events[3]

          expect(clients_call.payload[:includes]).to eq({})
          expect(client_1_call.payload[:includes]).to eq([:location])
          expect(client_2_call.payload[:includes]).to eq([:location])
          expect(client_3_call.payload[:includes]).to eq([:location])
        end

        it 'does not over/under include' do
          Bullet.start_request
          result = GraphQLSchema.execute(
            query_string,
            variables: {},
            context: {}
          ).to_h
          expect(result['errors']).to be_nil
          Bullet.perform_out_of_channel_notifications if Bullet.notification?
          Bullet.end_request
        end
      end

      context 'with nodes then edges' do
        let(:query_string) do
          <<-GQL
          query {
            clients {
              nested_query {
                nodes {
                  name
                  location {
                    name
                  }
                }
                edges {
                  completed
                }
              }
            }
          }
          GQL
        end

        it 'generates the correct includes pattern' do
          received_events = []
          subscription = ActiveSupport::Notifications.subscribe('graphql_includable.includes') do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            received_events << event
          end

          GraphQLSchema.execute(query_string, variables: {}, context: {})
          ActiveSupport::Notifications.unsubscribe(subscription)

          expect(received_events.length).to eq(7)
          clients_call = received_events[0]
          client_nodes_1_call = received_events[1]
          client_edges_1_call = received_events[2]
          client_nodes_2_call = received_events[3]
          client_edges_2_call = received_events[4]
          client_nodes_3_call = received_events[5]
          client_edges_3_call = received_events[6]

          expect(clients_call.payload[:includes]).to eq({})
          expect(client_nodes_1_call.payload[:includes]).to eq([:location])
          expect(client_nodes_2_call.payload[:includes]).to eq([:location])
          expect(client_nodes_3_call.payload[:includes]).to eq([:location])
          expect(client_edges_1_call.payload[:includes]).to eq({})
          expect(client_edges_2_call.payload[:includes]).to eq({})
          expect(client_edges_3_call.payload[:includes]).to eq({})
        end

        it 'does not over/under include' do
          Bullet.start_request
          result = GraphQLSchema.execute(
            query_string,
            variables: {},
            context: {}
          ).to_h
          expect(result['errors']).to be_nil
          Bullet.perform_out_of_channel_notifications if Bullet.notification?
          Bullet.end_request
        end
      end

      context 'with edges then nodes' do
        let(:query_string) do
          <<-GQL
          query {
            clients {
              nested_query {
                edges {
                  completed
                }
                nodes {
                  name
                  location {
                    name
                  }
                }
              }
            }
          }
          GQL
        end

        it 'generates the correct includes pattern' do
          received_events = []
          subscription = ActiveSupport::Notifications.subscribe('graphql_includable.includes') do |*args|
            event = ActiveSupport::Notifications::Event.new(*args)
            received_events << event
          end

          GraphQLSchema.execute(query_string, variables: {}, context: {})
          ActiveSupport::Notifications.unsubscribe(subscription)

          expect(received_events.length).to eq(7)
          clients_call = received_events[0]
          client_nodes_1_call = received_events[2]
          client_edges_1_call = received_events[1]
          client_nodes_2_call = received_events[4]
          client_edges_2_call = received_events[3]
          client_nodes_3_call = received_events[6]
          client_edges_3_call = received_events[5]

          expect(clients_call.payload[:includes]).to eq({})
          expect(client_nodes_1_call.payload[:includes]).to eq([:location])
          expect(client_nodes_2_call.payload[:includes]).to eq([:location])
          expect(client_nodes_3_call.payload[:includes]).to eq([:location])
          expect(client_edges_1_call.payload[:includes]).to eq({})
          expect(client_edges_2_call.payload[:includes]).to eq({})
          expect(client_edges_3_call.payload[:includes]).to eq({})
        end

        it 'does not over/under include' do
          Bullet.start_request
          result = GraphQLSchema.execute(
            query_string,
            variables: {},
            context: {}
          ).to_h
          expect(result['errors']).to be_nil
          Bullet.perform_out_of_channel_notifications if Bullet.notification?
          Bullet.end_request
        end
      end

      context 'with a conditional internal query' do
        let(:query_string) do
          <<-GQL
          query Conditional($continue_includes: Boolean!) {
            clients {
              new_chain(continue_includes: $continue_includes) {
                nodes {
                  name
                  location {
                    name
                  }
                }
              }
            }
          }
          GQL
        end

        context 'when the includes are chained' do
          let(:variables) { { 'continue_includes' => true } }
          it 'generates the correct includes pattern' do
            received_events = []
            subscription = ActiveSupport::Notifications.subscribe('graphql_includable.includes') do |*args|
              event = ActiveSupport::Notifications::Event.new(*args)
              received_events << event
            end

            GraphQLSchema.execute(query_string, operation_name: 'Conditional', variables: variables, context: {})
            ActiveSupport::Notifications.unsubscribe(subscription)

            expect(received_events.length).to eq(1)
            expect(received_events[0].payload[:includes]).to eq(tasks: [:location])
          end

          it 'does not over/under include' do
            Bullet.start_request
            result = GraphQLSchema.execute(
              query_string,
              variables: variables,
              context: {}
            ).to_h
            expect(result['errors']).to be_nil
            Bullet.perform_out_of_channel_notifications if Bullet.notification?
            Bullet.end_request
          end
        end

        context 'when the includes are not chained' do
          let(:variables) { { 'continue_includes' => false } }
          it 'generates the correct includes pattern' do
            received_events = []
            subscription = ActiveSupport::Notifications.subscribe('graphql_includable.includes') do |*args|
              event = ActiveSupport::Notifications::Event.new(*args)
              received_events << event
            end

            GraphQLSchema.execute(query_string, operation_name: 'Conditional', variables: variables, context: {})
            ActiveSupport::Notifications.unsubscribe(subscription)

            expect(received_events.length).to eq(4)
            clients_call = received_events[0]
            new_chain_1_call = received_events[1]
            new_chain_2_call = received_events[2]
            new_chain_3_call = received_events[3]

            expect(clients_call.payload[:includes]).to eq({})
            expect(new_chain_1_call.payload[:includes]).to eq([:location])
            expect(new_chain_2_call.payload[:includes]).to eq([:location])
            expect(new_chain_3_call.payload[:includes]).to eq([:location])
          end

          it 'does not over/under include' do
            Bullet.start_request
            result = GraphQLSchema.execute(
              query_string,
              variables: variables,
              context: {}
            ).to_h
            expect(result['errors']).to be_nil
            Bullet.perform_out_of_channel_notifications if Bullet.notification?
            Bullet.end_request
          end
        end
      end
    end

    context 'for an incorrectly configured schema' do
      let(:query_string) do
        <<-GQL
        query {
          clients {
            over_fetched {
              edges {
                completed
              }
            }
          }
        }
        GQL
      end

      it 'overfetches anyway' do
        Bullet.start_request
        expect do
          GraphQLSchema.execute(
            query_string,
            variables: {},
            context: {}
          )
          Bullet.perform_out_of_channel_notifications if Bullet.notification?
          Bullet.end_request
        end.to raise_error(Bullet::Notification::UnoptimizedQueryError)
      end
    end
  end
end
