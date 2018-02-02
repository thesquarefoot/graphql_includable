require 'graphql'
require 'graphql_includable/concern'
require 'graphql_includable/edge'

GraphQL::Field.accepts_definitions(
  includes: GraphQL::Define.assign_metadata_key(:includes)
)
