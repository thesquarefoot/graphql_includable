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
  include GraphQLIncludable
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
