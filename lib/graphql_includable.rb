require "graphql"
require "active_support/concern"

GraphQL::Field.accepts_definitions includes: GraphQL::Define.assign_metadata_key(:includes)

module GraphQLIncludable
  extend ActiveSupport::Concern

  module ClassMethods
    def includes_from_graphql(query_context)
      generated_includes = GraphQLIncludable.generate_includes_from_graphql(query_context, self.model_name.to_s)
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

  private

  def self.generate_includes_from_graphql(query_context, model_name)
    matching_node = GraphQLIncludable.find_child_node_matching_model_name(query_context.irep_node, model_name)
    GraphQLIncludable.includes_from_irep_node(matching_node)
  end

  def self.find_child_node_matching_model_name(node, model_name)
    matching_node = nil
    return_type = unwrapped_type(node)
    if return_type.to_s == model_name
      matching_node = node
    elsif node.respond_to? :scoped_children
      node.scoped_children[return_type].each do |child_name, child_node|
        matching_node = find_child_node_matching_model_name(child_node, model_name)
        break if matching_node
      end
    end
    matching_node
  end

  def self.includes_from_irep_node(node)
    includes = []
    nested_includes = {}

    return_type = unwrapped_type(node)
    return_model = node_return_class(node)
    return [] unless node && return_type && return_model

    node.scoped_children[return_type].each do |child_name, child_node|
      child_association_name, explicit_includes = suggested_association_name(child_name, child_node)
      association, delegated_model_name = find_association(return_model, child_association_name)
      if association
        child_includes = includes_from_irep_node(child_node)

        if node_has_active_record_children(child_node) && child_includes.size > 0
          nested_includes[delegated_model_name || child_association_name] = wrap_delegate(child_includes, delegated_model_name, child_association_name)
        else
          includes << wrap_delegate(child_association_name, delegated_model_name)
        end
      elsif explicit_includes
        includes << explicit_includes
      end
    end

    includes << nested_includes if nested_includes.size > 0
    includes
  end

  def self.node_has_active_record_children(node)
    node.scoped_children[unwrapped_type(node)].each do |child_return_name, child_node|
      node_returns_active_record?(child_node)
    end
  end

  def self.node_return_class(node)
    begin
      Object.const_get(unwrapped_type(node).name)
    rescue NameError
    end
  end

  def self.node_returns_active_record?(node)
    klass = node_return_class(node)
    klass && klass < ActiveRecord::Base
  end

  # return raw contents, or contents wrapped in a hash (for delegated associations)
  def self.wrap_delegate(contents, delegate, delegate_key = delegate)
    return contents unless delegate

    obj = {}
    obj[delegate_key] = contents
    obj
  end

  # unwrap GraphQL ListType and NonNullType wrappers
  def self.unwrapped_type(node)
    type = node.return_type
    type = type.of_type while type.respond_to? :of_type
    type
  end

  # find a valid association on return_model, following method delegation
  def self.find_association(return_model, child_name)
    delegated_model = return_model.instance_variable_get('@delegate_cache').try(:[], child_name.to_sym)
    association_model = delegated_model ? return_model.reflect_on_association(delegated_model).klass : return_model
    association = association_model.reflect_on_association(child_name)

    [association, delegated_model]
  end

  # find the association to look for based on a field definition
  # precedence is `includes` key, then `property` key, then the field name
  def self.suggested_association_name(name, node)
    includes_metadata = node.definitions[0].metadata[:includes]

    assoc_name = node.definitions[0].property || name
    assoc_name = includes_metadata if includes_metadata && includes_metadata.is_a?(Symbol)

    [assoc_name.to_sym, includes_metadata]
  end

end
