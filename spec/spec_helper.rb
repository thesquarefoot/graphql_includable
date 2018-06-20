require 'active_support'
require 'active_record'
require 'graphql'
require 'graphql_includable'

require 'test_models'
require 'test_schema'

private_includes = nil

shared_examples 'graphql' do
  before(:each) { private_includes = nil }
  let(:includes) { private_includes }
  let(:query) do
    GraphQL::ObjectType.define do
      name 'TestQuery'
      field :apple, AppleType do
        resolve ->(_obj, _args, ctx) do
          private_includes = Apple.all.includes_from_graphql(ctx).includes_values
          nil
        end
      end
      field :tree, TreeType do
        resolve ->(_obj, _args, ctx) do
          private_includes = Tree.all.includes_from_graphql(ctx).includes_values
          nil
        end
      end
      field :orchard, OrchardType do
        resolve ->(_obj, _args, ctx) do
          private_includes = Tree.all.includes_from_graphql(ctx).includes_values
          nil
        end
      end
    end
  end
  let(:schema) do
    GraphQL::Schema.define(query: query) do
      resolve_type ->(_type, obj, _ctx) { Object.const_get("#{obj.class}Type") }
    end
  end
end

def mock_schema_with_fields(fields)
  base_query = GraphQL::ObjectType.define do
    fields.each do |key, object_type|
      field key.to_sym, object_type do
        resolve ->(_obj, _args, ctx) do
          42
        end
      end
    end
  end
  GraphQL::Schema.define(query: base_query) do
    resolve_type ->(_type, obj, _ctx) {
      Object.const_get("#{obj.class}Type")
    }
  end
end

def irep_selection_from_query(schema, query)
  q = GraphQL::Query.new(schema, query)
  validator = GraphQL::StaticValidation::Validator.new(schema: schema)
  byebug
  validator.validate(q)[:irep].operation_definitions.first.last
end
