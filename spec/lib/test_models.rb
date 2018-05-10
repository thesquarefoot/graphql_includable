class TestModel < ActiveRecord::Base
  include GraphQLIncludable::Concern

  has_one :has_one
  has_many :has_many
  has_many :has_many_through_join
  has_many :has_many_through, through: :has_many_through_join

  has_one :delegate
  delegates :delegated_method, to: :delegate
end

class HasOne < ActiveRecord::Base; end
class HasMany < ActiveRecord::Base; end
class HasManyThroughJoin < ActiveRecord::Base; end
class HasManyThrough < ActiveRecord::Base; end
class Delegate < ActiveRecord::Base; end

TestModelType = GraphQL::ObjectType.define do
end

TestSchema = GraphQL::Schema.define(
  query: GraphQL::ObjectType.define do
    name 'BaseQuery'
    field :test_model, !types[!types.String] do
      resolve ->(_obj, _args, ctx) do
        TestModelType.includes_from_graphql(ctx).includes_values
      end
    end
  end
) do
  resolve_type ->(_type, obj, _ctx) { Object.const_get("#{obj.class}Type") }
end
