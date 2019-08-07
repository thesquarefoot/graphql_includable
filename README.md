# graphql_includable
> Eager-load graphql-ruby query data using Rails models

graphql_includable is an `ActiveSupport::Concern` for use with data models.
When resolving a GraphQL query with this model at the root, graphql_includable will eager-load all queried models using [`ActiveRecord::QueryMethods::includes`](https://apidock.com/rails/ActiveRecord/QueryMethods/includes).

## Usage

1. Include this concern in models which will be queried at the root, and define your relationships as ActiveRecord associations.

```ruby
class Apple < ActiveRecord::Base
  belongs_to :tree
end

class Tree < ActiveRecord::Base
  include GraphQLIncludable::Concern
  has_many :apples
end
```

2. Call `includes_from_graphql` when resolving the query, passing in the query context.

```ruby
BaseQuery = GraphQL::ObjectType.define do
  field :tree, TreeType do
    argument :id, !types.ID
    resolve -> (obj, args, ctx) {
      Tree.includes_from_graphql(ctx).find_by(args.to_h)
    }
  end
end
```

When resolving this query, `apples` will be preloaded (using `Tree.includes(:apples)`)

### Overrides

This gem attempts to detect what associations you want to preload by the field's name or its `property` attribute.
If this is inaccurate or ineffective, you can specify what to include in the field definition.

```ruby
TreeType = GraphQL::ObjectType.define do
  name "Tree"
  field :apples, !types[!AppleType]
  field :yabloki, !types[!AppleType], property: :apples
  field :fruit, types[AppleType], includes: :apples
  field :fruitWithSeeds, types[AppleType], includes: { apples: :seeds }
end
```

### Connection Support

Edges and node associations will be added to the `includes` pattern. Asking for only `nodes` will not include the edge association.

```ruby
class Survey < ApplicationRecord
  has_many :survey_listings # edges
  has_many :listings, through: :survey_listings # nodes through edges
end

SurveyType = GraphQL::ObjectType.define do
  connection :listings, ListingType.define_connection_with_fetched_edge(edge_type: SurveyListingEdgeType) do
    argument :liked, types.Boolean

    # Define how to fetch nodes directly and indirectly through edges
    includes(edges: :survey_listings, nodes: :listings)
    edge_to_node_property(:listing)

    # Optionally specify resolvers for nodes and edges
    resolve_edges ->(survey, args, ctx) do
      # survey.association(:survey_listings).loaded? == true
      # survey.survey_listings.each { |survey_listing| survey_listing.association(:listing).loaded? == true }

      return survey.liked_survey_listings if args[:liked]
      survey.survey_listings
    end

    resolve_nodes ->(survey, args, ctx) do
      # survey.association(:listings).loaded? == true

      return survey.liked_listings if args[:liked]
      survey.listings
    end
  end
end

GraphQLSchema = GraphQL::Schema.define do
  query BaseQuery
  mutation BaseMutation

  # Add this instrumentation
  instrument(:field, GraphQLIncludable::Relay::Instrumentation::Connection.new)
end


```