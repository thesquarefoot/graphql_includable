AppleType = GraphQL::ObjectType.define do
  name 'Apple'
  field :tree, !TreeType
  field :seeds, !types[types.String]
  field :juice, !types.Int
end

ApplesConnectionType = AppleType.define_connection

TreeType = GraphQL::ObjectType.define do
  name 'Tree'
  field :apples, !types[!AppleType]
  field :yabloki, !types[!AppleType], property: :apples
  field :worms, !types[!WormType]
  field :fruit, types[AppleType], includes: :apples
  field :fruitWithTree, types[AppleType], includes: { apples: [:tree] }, property: :fruit
  field :roots, !TreeRootsType, property: :tree_roots
  connection :apples_connection, ApplesConnectionType, property: :apples
end

TreeRootsType = GraphQL::ObjectType.define do
  name 'TreeRoots'
  field :tree, !TreeType
  field :worms, !types[!WormType]
end

WormType = GraphQL::ObjectType.define do
  name 'Worm'
  field :apple, !AppleType
end

OrchardType = GraphQL::ObjectType.define do
  name 'Orchard'
  field :name, !types.String
  field :trees, !types[!TreeType]
end
