# rubocop:disable Style/ConditionalAssignment
# rubocop:disable Lint/HandleExceptions
# rubocop:disable Metrics/AbcSize
module GraphQLIncludable
  class Edge < GraphQL::Relay::Edge
    def edge
      return @edge if @edge
      join_chain = joins_along_edge
      edge_class_name = join_chain.shift
      edge_class = str_to_class(edge_class_name)

      root_association_key = class_to_str(parent.class)
      unless edge_class.reflections.keys.include?(root_association_key)
        is_polymorphic = true
        root_association_key = edge_class.reflections.select { |_k, r| r.polymorphic? }.keys.first
      end

      if parent.class.delegate_cache&.key?(edge_class_name)
        root_association_search_value = parent.send(parent.class.delegate_cache[edge_class_name])
      else
        root_association_search_value = parent
      end

      root_node = { root_association_key.to_sym => [root_association_search_value] }
      terminal_node = { class_to_str(node.class) => node }
      join_chain.reverse.each do |rel_name|
        terminal_node = { rel_name.to_s.pluralize => terminal_node }
      end

      search_hash = root_node.merge(terminal_node)
      edge_includes = join_chain.map { |s| s.to_s.singularize }
      edge_class = edge_class.includes(*edge_includes) unless edge_includes.empty?
      edge_class = edge_class.joins(root_association_key.to_sym) unless is_polymorphic
      @edge ||= edge_class.find_by(search_hash)
    end

    def method_missing(method_name, *args, &block)
      if edge.respond_to?(method_name)
        edge.send(method_name, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      edge.respond_to?(method_name) || super
    end

    private

    def str_to_class(str)
      str.to_s.singularize.camelize.constantize
    rescue
    end

    def class_to_str(klass)
      klass.name.downcase
    end

    def joins_along_edge
      # node.edges
      # edge.node
      # edge.parent
      # parent.edges
      # node.parents
      # parent.nodes
      edge_association_name = node.class.name.pluralize.downcase.to_sym
      if parent.class.delegate_cache&.key?(edge_association_name)
        parent_class = str_to_class(parent.class.delegate_cache[edge_association_name])
      else
        parent_class = parent.class
      end
      edge_association = parent_class.reflect_on_association(edge_association_name)
      edge_joins = []
      while edge_association.is_a? ActiveRecord::Reflection::ThroughReflection
        edge_joins.unshift edge_association.options[:through]
        edge_association = parent_class.reflect_on_association(edge_association.options[:through])
      end
      edge_joins
      # join_chain = []
      # starting_class = parent.class
      # node_relationship_name = class_to_str(node.class)
      # while starting_class
      #   reflection = starting_class.reflect_on_association(node_relationship_name)
      #   association_name = reflection&.options&.try(:[], :through)
      #   join_chain << association_name if association_name
      #   starting_class = str_to_class(association_name)
      #   node_relationship_name = node_relationship_name.singularize
      # end
      # join_chain
    end
  end
end
