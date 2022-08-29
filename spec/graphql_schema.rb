GraphQL::Relay::ConnectionType.default_nodes_field = true

class BaseObject < GraphQL::Schema::Object
  connection_type_class(GraphQL::Types::Relay::BaseConnection)

  def self.define_connection_with_fetched_edge(**kwargs, &block)
    GraphQLIncludable::Relay::EdgeWithNodeConnectionType.create_type(
      self,
      **kwargs,
      &block
    )
  end
end

class IncludableField < GraphQL::Schema::Field
  # maybe just need to wrap in a accepts_definition?
  def initialize(*args, includes: nil, **kwargs, &block)
    @includes = includes
    super(*args, **kwargs, &block)
  end

  def includes(*args)
    args
  end
  # def resolve(type, args, ctx)
  #   return super unless @includess

  #   BatchLoader::GraphQL.for(type).batch(key: self) do |records, loader|
  #     ActiveRecord::Associations::Preloader.new.preload(records.map(&:object), @includes)
  #     records.each { |r| loader.call(r, super(r, args, ctx)) }
  #   end
  # end
end

# Define how to get from an edge Active Record model to the node Active Record model
IncludableField.accepts_definition(:connection_properties)

# Define a resolver for connection edges records
IncludableField.accepts_definition(:resolve_edges)

# # Define a resolver for connection nodes records
IncludableField.accepts_definition(:resolve_nodes)

# # Internally used to mark a connection type that has a fetched edge
IncludableField.accepts_definition(:_includable_connection_marker)

class UserType < BaseObject
  graphql_name 'User'
  field :name, String, null: false
  field :email, String, null: false
  # field :array_clients, [ClientType, { null: false }], null: false, method: :clients, includes: :clients
  # field :clients, ClientType.define_connection, null: true, connection: true do
  #   includes ->(_args, _ctx) { nodes(:clients) }
  # end

  def clients
    raise 'Missing includes' unless object.association(:clients).loaded?

    object.clients
  end
end

class LocationType < BaseObject
  graphql_name 'Location'
  field :name, String, null: false
end

class TaskType < BaseObject
  graphql_name 'Task'
  field_class IncludableField

  field :name, String, null: false
  field :location, LocationType, null: false, includes: :location
end

ClientTaskEdgeType = TaskType.define_edge do
  field :completed, Boolean, null: false
end

OverFetchedConnectionType = TaskType.define_connection_with_fetched_edge(edge_type: ClientTaskEdgeType) do
  name 'OverFetchedConnection'
end

NestedQueryConnectionType = TaskType.define_connection_with_fetched_edge(edge_type: ClientTaskEdgeType) do
  name 'NestedQueryConnection'
end

class ClientType < BaseObject
  graphql_name 'Client'
  field_class IncludableField

  field :name, String, null: false
  field :user, UserType, null: false, includes: :user
  field :array_tasks, [TaskType, { null: false }], null: false, method: :tasks do
    includes ->() do
      path(:client_tasks, :task)
    end
  end

  field :tasks, TaskType.define_connection_with_fetched_edge(edge_type: ClientTaskEdgeType), null: true, connection: true do
    connection_properties(nodes: :tasks, edges: :client_tasks, edge_to_node: :task)

    includes ->() do
      nodes(:tasks)
      edges do
        path(:client_tasks)
        node(:task)
      end
    end
  end

  field :over_fetched, OverFetchedConnectionType, null: true, connection: true do
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

  field :nested_query, NestedQueryConnectionType, null: true, connection: true do
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

  field :new_chain, TaskType.define_connection(edge_type: ClientTaskEdgeType) { name 'NewChainConnection' }, null: true, connection: true do
    argument :continue_includes, Boolean, required: true
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

class BaseQuery < GraphQL::ObjectType
  name 'BaseQuery'
  field :users, [UserType, { null: false }], null: false
  field :clients, [ClientType, { null: false }], null: false

  def users(_obj, _args, ctx)
    User.includes(GraphQLIncludable.includes(ctx)).all
  end

  def clients(_obj, _args, ctx)
    Client.includes(GraphQLIncludable.includes(ctx)).all
  end
end

class GraphQLSchema < GraphQL::Schema
  query BaseQuery
  instrument(:field, GraphQLIncludable::Relay::Instrumentation.new)
  resolve_type ->(_type, obj, _ctx) { Object.const_get("#{obj.class}Type") }
end
