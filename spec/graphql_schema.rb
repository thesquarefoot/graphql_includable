GraphQL::Relay::ConnectionType.default_nodes_field = true

UserType = GraphQL::ObjectType.define do
  name 'User'
  field :name, !types.String
  field :email, !types.String
  field :array_clients, !types[!ClientType], property: :clients, includes: :clients
  connection :clients, ClientType.define_connection do
    includes ->() { nodes(:clients) }

    resolve ->(user, _args, _ctx) do
      raise 'Missing includes' unless user.association(:clients).loaded?
      user.clients
    end
  end
end

LocationType = GraphQL::ObjectType.define do
  name 'Location'
  field :name, !types.String
end

TaskType = GraphQL::ObjectType.define do
  name 'Task'
  field :name, !types.String
  field :location, !LocationType, includes: :location
end

ClientTaskEdgeType = TaskType.define_edge do
  field :completed, !types.Boolean
end

OverFetchedConnectionType = TaskType.define_connection_with_fetched_edge(edge_type: ClientTaskEdgeType) do
  name 'OverFetchedConnection'
end

NestedQueryConnectionType = TaskType.define_connection_with_fetched_edge(edge_type: ClientTaskEdgeType) do
  name 'NestedQueryConnection'
end

ClientType = GraphQL::ObjectType.define do
  name 'Client'
  field :name, !types.String
  field :user, !UserType, includes: :user
  field :array_tasks, !types[!TaskType], property: :tasks do
    includes ->() do
      path(:client_tasks, :task)
    end
  end

  connection :tasks, TaskType.define_connection_with_fetched_edge(edge_type: ClientTaskEdgeType) do
    connection_properties(nodes: :tasks, edges: :client_tasks, edge_to_node: :task)

    includes ->() do
      nodes(:tasks)
      edges do
        path(:client_tasks)
        node(:task)
      end
    end
  end

  connection :over_fetched, OverFetchedConnectionType do
    connection_properties(edge_to_node: :task)

    includes ->() do
      nodes(:tasks)
      edges do
        path(:client_tasks)
        node(:task)
      end
    end

    resolve_edges ->(_client, _args, _ctx) do
      []
    end

    resolve_nodes ->(_client, _args, _ctx) do
      []
    end
  end

  connection :nested_query, NestedQueryConnectionType do
    connection_properties(edge_to_node: :task)

    includes ->() do
      edges { node(:task) }
    end

    resolve_edges ->(_client, _args, ctx) do
      ClientTask.includes(GraphQLIncludable.includes(ctx)).all
    end

    resolve_nodes ->(_client, _args, ctx) do
      Task.includes(GraphQLIncludable.includes(ctx)).all
    end
  end

  connection :new_chain, TaskType.define_connection(edge_type: ClientTaskEdgeType) { name 'NewChainConnection' } do
    argument :continue_includes, !types.Boolean
    includes ->(args, _ctx) do
      return unless args[:continue_includes]
      nodes(:tasks)
    end

    resolve ->(client, args, ctx) do
      return client.tasks if args[:continue_includes]
      Task.includes(GraphQLIncludable.includes(ctx)).all
    end
  end
end

GraphQLSchema = GraphQL::Schema.define(
  query: GraphQL::ObjectType.define do
    name 'BaseQuery'
    field :users, !types[!UserType] do
      resolve ->(_obj, _args, ctx) do
        User.includes(GraphQLIncludable.includes(ctx)).all
      end
    end

    field :clients, !types[!ClientType] do
      resolve ->(_obj, _args, ctx) do
        Client.includes(GraphQLIncludable.includes(ctx)).all
      end
    end
  end
) do
  instrument(:field, GraphQLIncludable::Relay::Instrumentation.new)
  resolve_type ->(_type, obj, _ctx) { Object.const_get("#{obj.class}Type") }
end
