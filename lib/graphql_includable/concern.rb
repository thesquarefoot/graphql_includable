require 'active_support/concern'

module GraphQLIncludable
  module Concern
    extend ActiveSupport::Concern

    module ClassMethods
      def includes_from_graphql(ctx)
        node = GraphQLIncludable::Concern.first_child_by_return_type(ctx.irep_node, model_name.to_s)
        generated_includes = Concern.includes_from_graphql_node(node)
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

    def self.first_child_by_return_type(node, model_name)
      matching_node = nil
      return_type = node.return_type.unwrap
      if return_type.to_s == model_name
        matching_node = node
      elsif node.respond_to?(:scoped_children)
        node.scoped_children[return_type].each_value do |child_node|
          matching_node = first_child_by_return_type(child_node, model_name)
          break if matching_node
        end
      end
      matching_node
    end

    def self.children_through_connection(node, return_model)
      children = node.scoped_children[node.return_type.unwrap]
      includes = {}

      if node_is_relay_connection?(node)
        all_children = children['edges'].scoped_children[children['edges'].return_type.unwrap]
        children = all_children.except('node')

        target_node = all_children['node']
        target_association = return_model.reflect_on_association(node_return_class(target_node).name.underscore)
        includes[target_association.name] = includes_from_graphql_node(target_node)
      end

      [children, includes]
    end

    def self.includes_from_graphql_node(node)
      return_model = node_return_class(node)
      return [] unless return_model

      includes = []
      children, nested_includes = children_through_connection(node, return_model)

      children.each_value do |child_node|
        child_includes = includes_from_graphql_child(child_node, return_model)

        if child_includes.is_a?(Hash)
          nested_includes.merge!(child_includes)
        else
          includes += child_includes.is_a?(Array) ? child_includes : [child_includes]
        end
      end

      includes << nested_includes unless nested_includes.blank?
      includes.uniq
    end

    def self.includes_from_graphql_child(child_node, return_model)
      specified_includes = child_node.definitions[0].metadata[:includes]
      attribute_name = node_predicted_association_name(child_node)
      includes_chain = delegated_includes_chain(return_model, attribute_name)
      association = get_model_association(return_model, attribute_name, includes_chain)

      if association
        child_includes = includes_from_graphql_node(child_node)
        join_name = (specified_includes || attribute_name)

        if node_is_relay_connection?(child_node)
          join_name = association.options[:through]
          edge_includes_chain = [association.name]
          edge_includes_chain << child_includes.pop[association.name.to_s.singularize.to_sym] if child_includes.last&.is_a?(Hash)
          edge_includes = array_to_nested_hash(edge_includes_chain)
        end

        includes_chain << join_name
        includes_chain << child_includes unless child_includes.blank?

        [edge_includes, array_to_nested_hash(includes_chain)].reject(&:blank?)
      else
        includes = []
        includes << array_to_nested_hash(includes_chain) unless includes_chain.blank?
        includes << specified_includes if specified_includes
        includes
      end
    end

    def self.node_return_class(node)
      # rubocop:disable Lint/HandleExceptions, Style/RedundantBegin
      begin
        Object.const_get(node.return_type.unwrap.name.gsub(/(^SquareFoot|Edge$|Connection$)/, ''))
      rescue NameError
      end
      # rubocop:enable Lint/HandleExceptions, Style/RedundantBegin
    end

    def self.node_is_relay_connection?(node)
      node.return_type.unwrap.name =~ /Connection$/
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

    def self.get_model_association(model, association_name, includes_chain = nil)
      delegated_model = model_name_to_class(includes_chain.last) unless includes_chain.blank?
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
end
