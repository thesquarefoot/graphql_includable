module GraphQLIncludable
  class Edge < GraphQL::Relay::Edge
    def edge
      return @edge if @edge

      all_association_names = associations_between_node_and_parent
      first_association_name = all_association_names.shift
      other_association_names = all_association_names.map { |s| s.to_s.singularize }

      edge_class = self.class.str_to_class(first_association_name)
      is_polymorphic = edge_class.reflections.none? { |k, r| r.polymorphic? }

      selector = edge_class
      selector = selector.merge(edge_class.includes(*other_association_names)) if other_association_names.present?
      selector = selector.merge(edge_class.joins(root_association_key.to_sym)) unless is_polymorphic
      selector = selector.find_by(where_hash_for_edge(edge_class, all_association_names))

      @edge ||= selector
    end

    def method_missing(method_name, *args, &block)
      if edge.respond_to?(method_name)
        edge.send(method_name, *args, &block)
      else
        super
      end
    end

    def respond_to_missing(method_name, include_private = false)
      edge.respond_to?(method_name) || super
    end

    private
    def associations_between_node_and_parent
      return @associations if @associations.present?

      associations = []
      association_name = node.class.name.pluralize.downcase.to_sym
      association = parent.class.reflect_on_association(association_name)
      while association.is_a?(ActiveRecord::Reflection::ThroughReflection)
        associations.unshift(association.options[:through])
        association = parent.class.reflect_on_association(association.options[:through])
      end

      @associations = associations
    end

    def where_hash_for_edge(edge_class, association_names)
      root_association_key = self.class.class_to_str(parent.class)
      unless edge_class.reflections.keys.include?(root_association_key)
        root_association_key = edge_class.reflections.select { |k, r| r.polymorphic? }.keys.first
      end
      root_include = { root_association_key.to_sym => [parent] }

      terminal_include = { self.class.class_to_str(node.class) => node }
      association_names.reverse.each do |rel_name|
        terminal_include = { rel_name.to_s.pluralize => terminal_include }
      end

      root_include.merge(terminal_include)
    end

    class << self
      private
      def str_to_class(str)
        str.to_s.singularize.camelize.constantize
      rescue
      end

      def class_to_str(klass)
        klass.name.downcase
      end
    end
  end
end
