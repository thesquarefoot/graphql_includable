# graphql_includable
> Eager-load graphql-ruby query data using Rails models

When resolving a GraphQL query with this model at the root, graphql_includable will eager-load all queried models using [`ActiveRecord::QueryMethods::includes`](https://apidock.com/rails/ActiveRecord/QueryMethods/includes).

## Usage

1. Define your relationships as ActiveRecord associations.

```ruby
class Apple < ActiveRecord::Base
  belongs_to :tree
end

class Tree < ActiveRecord::Base
  has_many :apples
end
```

2. Annotated your GraphQL fields with `includes`

```ruby
AppleType = GraphQL::ObjectType.define do
  name "Apple"
  field :tree, !types[!TreeType], includes :tree
end

TreeType = GraphQL::ObjectType.define do
  name "Tree"
  field :apples, !types[!AppleType], includes :apples
end
```

3. Call `GraphQLIncludable.includes` when resolving the query, passing in the query context.


```ruby
BaseQuery = GraphQL::ObjectType.define do
  field :tree, TreeType do
    argument :id, !types.ID
    resolve -> (obj, args, ctx) {
      includes = GraphQLIncludable.includes(ctx)
      Tree.includes(includes).find_by(args.to_h)
    }
  end
end
```

When resolving a query for `tree.apples`, the association `apples` will be preloaded on `Tree` because of the `includes` annotation on the field.

### Extra includes

`includes` can take a lambda that can be used to build up any `includes` pattern.

For example, let's say a `field` needs to include a grandchild association on the model.

```rb
class Building < ActiveRecord::Base
  has_one :location
class Location < ActiveRecord::Base
  has_one :address
end
class Address < ActiveRecord::Base
end

BuildingType = GraphQL::ObjectType.define do
  field :address, !AddressType do
    includes ->() {
      path(:location) {
        path(:address)
      }
    }
    resolve ->(building, args, ctx) {
      building.location.address
    }
  end
end
```

You can also include associations where child includes are not chained on.

```rb
class Building < ActiveRecord::Base
  has_one :location
class Location < ActiveRecord::Base
  has_one :address
  has_one :neighborhood
end
class Address < ActiveRecord::Base
end
class Neighborhood < ActiveRecord::Base
end

AddressType = GraphQL::ObjectType.define do
  field :street, !types.String
  field :city, !types.String
end

AddressWithNeighborhoodType = GraphQL::ObjectType.define do
  field :address, !AddressType
  field :neighborhood, !types.String
end

BuildingType = GraphQL::ObjectType.define do
  field :address, !AddressWithNeighborhoodType do
    includes ->() {
      path(:location) {
        path(:address) # Deeper includes would be added here { building: { location: [:neighborhood, { address: ... }] } }
        sibling_path(:neighborhood)
      }
    }
    resolve ->(building, args, ctx) {
      {
        address: building.location.address,
        neighborhood: building.location.neighborhood.name
      }
    }
  end
end
```

### Conditional includes generation

`includes` can take a lambda which can check the `args` and `ctx` to decide what to include.

```ruby
field :conditional_apples do
  argument :kind, !types.String
  includes ->(args, ctx) {
    return :red_delicious_apples if args[:kind] == 'Red Delicious'
    return :pink_pearl_apples if args[:kind] == 'Pink Pearls'
    :apples # fall back to including all apples
  }
  resolve ->(obj, args, ctx) {
    return tree.red_delicious_apples if args[:kind] == 'Red Delicious'
    return tree.pink_pearl_apples if args[:kind] == 'Pink Pearls'
    tree.apples
  }
end
```

### Connection Support

Edges and node associations will be added to the `includes` pattern. Asking for only `nodes` will not include the edge association.

As a simple example where a connection just has `nodes.

```ruby
connection :surveys do
  type SurveyType.define_connection
  argument :sent, types.Boolean

  includes ->(args, ctx) {
    nodes(:surveys) # When querying `nodes`, include association `surveys`
  }

  resolve ->(obj, inputs, ctx) {
    obj.surveys # Eagerly loaded
  }
end
```

Whenever your connection is backed by join-table modelling, you can use a custom connection type that will efficiently fetch edges and or nodes.

```ruby
class Survey < ActiveRecord::Base
  has_many :survey_listings
  has_many :listings, through: :survey_listings
end

class SurveyListing < ActiveRecord::Base
  belongs_to :listing
end

class Listing < ActiveRecord::Base
end

SurveyType = GraphQL::ObjectType.define do
  connection :listings, ListingType.define_connection_with_fetched_edge(edge_type: SurveyListingEdgeType) do
    # Tell fetched-edge-connection how to fetch `nodes` from Survey, `edges` from Survey
    # and how to get from a SurveyListing to the `node` Listing
    connection_properties(nodes: :listings, edges: :survey_listings, edge_to_node: :listing)

    includes ->() {
      nodes(:listings) # include :listings when querying nodes directly
      edges do
        path(:survey_listings)  # include :survey_listings when querying edges directly
        node(:listing)  # include SurveyListing's :listing association when querying edges then node
      end
    }
  end
end

GraphQLSchema = GraphQL::Schema.define do
  query BaseQuery
  mutation BaseMutation

  # Add this instrumentation
  instrument(:field, GraphQLIncludable::Relay::Instrumentation.new)
end
```

Examples of generated includes:

```rb
query {
  surveys {
    listings {
      nodes {
        id
      }
    }
  }
}
includes([:listings])

query {
  surveys {
    listings {
      edges {
        sent
      }
    }
  }
}
includes([:survey_listings])

query {
  surveys {
    listings {
      edges {
        sent
        node {
          id
        }
      }
    }
  }
}
includes({ survey_listings: [:listing] })
```

## Migrating from 0.4 to 0.5
With version 0.5 a new, more powerful GraphQLIncludable API has been introduced. This is currently namespaced behind `GraphQLIncludable::New` and
any associated attributes are prefixed with `new_`, for example `new_includes` vs the old API's `includes`.

Namespacing this API allows applications to run the old and new APIs side by side, there is no need for a big bang migration.

**Version 0.5 is the last verion to support the old API.**
You should migrate to version 0.5 before any future versions as `GraphQLIncludable::New` namespace and, more critically, the `new_` prefix will
be dropped from `new_includes`, interferring with and breaking the old `includes_from_graphql` API.

In order to simplify the implementation and improve connection support, ActiveRecord introspection was removed. This means your GraphQL `field`s
now require explicit annotation that they are to be evaluated for inclusion.

1. For all fields that use ActiveRecord associations add a `new_includes` annotation.
2. Add the following instrumentation to your query for Connection support
    ```rb
    instrument(:field, GraphQLIncludable::New::Relay::Instrumentation.new)
    ```
3. Start replacing calls to `Model.includes_from_graphql` with
    ```rb
    Model.includes(GraphQLIncludable::New.includes(ctx))
    ```
    You can control at which point in the GraphQL query to start generating includes from
    ```rb
    SearchType = GraphQL::ObjectType.define do
      name 'Search'

      field :count, !types.Int
      field :offset, !types.Int
      field :results, !types[ResultType]
    end

    SearchField = GraphQL::Field.define do
      type SearchType
      argument ...

      resolve ->(obj, args, ctx) {
        includes = GraphQLIncludable::New.includes(ctx, starting_at: :results)
        Result.includes(includes).where(...)
      }
    end
    ```


For example:
```ruby
AppleType = GraphQL::ObjectType.define do
  name "Apple"
  field :tree, !types[!TreeType]
end

TreeType = GraphQL::ObjectType.define do
  name "Tree"
  field :apples, !types[!AppleType]
end

BaseQuery = GraphQL::ObjectType.define do
  field :tree, TreeType do
    argument :id, !types.ID
    resolve -> (obj, args, ctx) {
      # Old API - generates includes(:apples)
      trees = Tree.includes_from_graphql(ctx).find_by(args.to_h) # No N+1 problems
      # New API - generates includes()
      includes = GraphQLIncludable::New.includes(ctx)
      Tree.includes(includes).find_by(args.to_h) # Would create N+1 problems
    }
  end
end
```

By annotating the types with `new_includes`, both the old and new API will work side by side.
```ruby
AppleType = GraphQL::ObjectType.define do
  name "Apple"
  field :tree, !types[!TreeType], new_includes: :tree
end

TreeType = GraphQL::ObjectType.define do
  name "Tree"
  field :apples, !types[!AppleType], new_includes: :apples
end

BaseQuery = GraphQL::ObjectType.define do
  field :tree, TreeType do
    argument :id, !types.ID
    resolve -> (obj, args, ctx) {
      # Old API - generates includes(:apples)
      trees = Tree.includes_from_graphql(ctx).find_by(args.to_h) # No N+1 problems
      # New API - generates includes(:apples)
      includes = GraphQLIncludable::New.includes(ctx)
      Tree.includes(includes).find_by(args.to_h) # No N+1 problems
    }
  end
end
```

## Migrating from 0.5 to 1.0

**Ensure you have migrated to the new API by following the above guidelines before continuing**

1. Remove any `includes:` overrides leftover from the old API. You may have already done this as part of the 0.5 release.
2. Rename any `new_includes` field annotations with `includes`
3. Replace calls to `new_define_connection_with_fetched_edge` with `define_connection_with_fetched_edge`
4. Replace schema instrumentation `instrument(:field, GraphQLIncludable::New::Relay::Instrumentation.new)` with `instrument(:field, GraphQLIncludable::Relay::Instrumentation.new)`
5. Replace includes generation statements `GraphQLIncludable::New.includes` with `GraphQLIncludable.includes`
6. Remove `include GraphQLIncludable::Concern` from your Active Record models

```ruby
AppleType = GraphQL::ObjectType.define do
  name "Apple"
  field :tree, !types[!TreeType], includes: :tree
end

TreeType = GraphQL::ObjectType.define do
  name "Tree"
  field :apples, !types[!AppleType], includes: :apples
end

BaseQuery = GraphQL::ObjectType.define do
  field :tree, TreeType do
    argument :id, !types.ID
    resolve -> (obj, args, ctx) {
      includes = GraphQLIncludable.includes(ctx)
      Tree.includes(includes).find_by(args.to_h)
    }
  end
end

GraphQLSchema = GraphQL::Schema.define do
  query BaseQuery
  mutation BaseMutation

  instrument(:field, GraphQLIncludable::Relay::Instrumentation.new)
end
```