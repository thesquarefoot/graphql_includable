describe GraphQLIncludable::New::Resolver do
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
      query {
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

    it 'works' do
      result = GraphQLSchema.execute(
        query_string,
        variables: {},
        context: {}
      ).to_h

      expect(result).to eq({
        'data' => {
          'users' => [
            {
              'name' => 'Jordan',
              'email' => 'jordan@example.com',
              'clients' => {
                'nodes' => [
                  {
                    'name' => '1',
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
              'name'=>'1',
              'user' => { 'name' => 'Jordan' },
              'tasks' => {
                'edges' => [
                  { 'completed' => false, 'node' => { 'name' => 'Task A' }},
                  { 'completed' => false, 'node' => { 'name' => 'Task B' }}
                ]
              }
            },
            {
              'name' => '2',
              'user' => { 'name' => 'Jordan' },
              'tasks' => {
                'edges' => [
                  { 'completed' => false, 'node' => { 'name'=>'Task C' }}
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
      })
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

      it 'includes the right amount' do
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

      it 'includes the right amount' do
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

      it 'includes the right amount' do
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

      it 'includes the right amount' do
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

      it 'includes the right amount' do
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

        it 'includes the right amount' do
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

        it 'includes the right amount' do
          Bullet.start_request
          result = GraphQLSchema.execute(
            query_string,
            variables: {},
            context: {}
          ).to_h
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

        it 'includes the right amount' do
          Bullet.start_request
          result = GraphQLSchema.execute(
            query_string,
            variables: {},
            context: {}
          ).to_h
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

        it 'includes the right amount', :focus  do
          Bullet.start_request
          result = GraphQLSchema.execute(
            query_string,
            variables: {},
            context: {}
          ).to_h
          Bullet.perform_out_of_channel_notifications if Bullet.notification?
          Bullet.end_request
        end
      end

      context 'with edges then nodes' do
        let(:query_string) do
          <<-GQL
          query {
            clients {
              edges {
                completed
              }
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

        it 'includes the right amount', :focus  do
          Bullet.start_request
          result = GraphQLSchema.execute(
            query_string,
            variables: {},
            context: {}
          ).to_h
          Bullet.perform_out_of_channel_notifications if Bullet.notification?
          Bullet.end_request
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
        expect {
          result = GraphQLSchema.execute(
            query_string,
            variables: {},
            context: {}
          ).to_h
          expect(result['errors']).to be_nil
          Bullet.perform_out_of_channel_notifications if Bullet.notification?
          Bullet.end_request
        }.to raise_error(Bullet::Notification::UnoptimizedQueryError)
      end
    end
  end
end
