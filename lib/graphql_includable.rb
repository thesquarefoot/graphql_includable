require 'graphql'
require 'active_support/concern'

GraphQL::Field.accepts_definitions(
  includes: GraphQL::Define.assign_metadata_key(:includes)
)

GraphQL::ObjectType.accepts_definitions(
  model: GraphQL::Define.assign_metadata_key(:model)
)

module GraphQLIncludable
  extend ActiveSupport::Concern

  module ClassMethods
    def includes_from_graphql(ctx)
      generated_includes = GraphQLIncludable.generate_includes_from_graphql(ctx, model_name.to_s)
      includes(generated_includes)
    end

    def delegate_cache
      @delegate_cache ||= {}
    end

    # hook ActiveSupport's delegate method to track models and where their delegated methods go
    def delegate(*methods, args)
      methods.each do |method|
        delegate_cache[method] = args[:to]
      end
      super(*methods, args) if defined?(super)
    end
  end

  def self.generate_includes_from_graphql(ctx, model_name)
    matching_node = find_child_returning_model_name(ctx.irep_node, model_name)
    includes_from_graphql_field(matching_node)
  end

  def self.find_child_returning_model_name(node, model_name)
    matching_node = nil
    return_type = node_return_type(node)
    if return_type.to_s == model_name
      matching_node = node
    elsif node.respond_to? :scoped_children
      node.scoped_children[return_type].each do |_child_name, child_node|
        matching_node = find_child_returning_model_name(child_node, model_name)
        break if matching_node
      end
    end
    matching_node
  end

  def self.includes_from_graphql_field(node)
    includes = []
    nested_includes = {}

    return_model = node_return_class(node)
    return [] unless node && return_model

    node.scoped_children[node_return_type(node)].each do |_child_name, child_node|
      child_includes = includes_from_graphql_child(child_node, return_model)
      if child_includes.is_a?(Hash)
        nested_includes.merge!(child_includes)
      else
        child_includes = [child_includes] unless child_includes.is_a?(Array)
        includes += child_includes
      end
    end

    includes << nested_includes unless nested_includes.empty?
    includes
  end

  def self.includes_from_graphql_child(child_node, return_model)
    specified_includes = child_node.definitions[0].metadata[:includes]
    attribute_name = node_predicted_association_name(child_node)
    includes_chain = delegated_includes_chain(return_model, attribute_name)

    if model_has_association?(return_model, attribute_name, includes_chain)
      child_includes = includes_from_graphql_field(child_node)
      includes_chain << (specified_includes || attribute_name)
      includes_chain << child_includes unless child_includes.empty?
      array_to_nested_hash(includes_chain)
    else
      includes = []
      includes << array_to_nested_hash(includes_chain) unless includes_chain.empty?
      includes << specified_includes if specified_includes
      includes
    end
  end

  def self.node_return_class(node)
    return_type = node_return_type(node)
    # rubocop:disable Lint/HandleExceptions
    begin
      return_type.metadata[:model] || Object.const_get(return_type.name)
    rescue NameError
    end
    # rubocop:enable Lint/HandleExceptions
  end

  def self.node_returns_active_record?(node)
    klass = node_return_class(node)
    klass && klass < ActiveRecord::Base
  end

  def self.node_predicted_association_name(node)
    definition = node.definitions[0]
    specified_includes = definition.metadata[:includes]
    if specified_includes.is_a?(Symbol)
      specified_includes
    else
      (definition.property || definition.name).to_sym
    end
  end

  # get unwrapped return type from a field, stripping ListType / NonNullType wrappers
  def self.node_return_type(node)
    type = node.return_type
    type = type.of_type while type.respond_to? :of_type
    type
  end

  def self.model_has_association?(model, association_name, includes_chain)
    delegated_model = model_name_to_class(includes_chain.last) unless includes_chain.empty?
    (delegated_model || model).reflect_on_association(association_name)
  end

  # get a 1d array of the chain of delegated model names,
  # so if model A delegates method B to model C, which delegates method B to model D,
  # delegated_includes_chain(A, :B) => [:C, :D]
  def self.delegated_includes_chain(base_model, method_name)
    chain = []
    method = method_name.to_sym
    model_name = base_model.instance_variable_get('@delegate_cache').try(:[], method)
    while model_name
      chain << model_name
      model = model_name_to_class(model_name)
      model_name = model.instance_variable_get('@delegate_cache').try(:[], method)
    end
    chain
  end

  # convert a 1d array into a nested hash
  # e.g. [:foo, :bar, :baz] => { :foo => { :bar => :baz }}
  def self.array_to_nested_hash(arr)
    arr.reverse.inject { |acc, item| { item => acc } }
  end

  # convert a model name into a class variable,
  # e.g. :search_parameters -> SearchParameters
  def self.model_name_to_class(model_name)
    begin
      model = model_name.to_s.camelize.constantize
    rescue NameError
      model = model_name.to_s.singularize.camelize.constantize
    end
    model
  end
end
