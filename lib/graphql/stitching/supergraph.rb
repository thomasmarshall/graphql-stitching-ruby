# frozen_string_literal: true

module GraphQL
  module Stitching
    class Supergraph
      LOCATION = "__super"
      INTROSPECTION_TYPES = [
        "__Schema",
        "__Type",
        "__Field",
        "__Directive",
        "__EnumValue",
        "__InputValue",
        "__TypeKind",
        "__DirectiveLocation",
      ].freeze

      attr_reader :schema, :boundaries, :locations_by_type_and_field, :executables

      def initialize(schema:, fields:, boundaries:, executables: {})
        @schema = schema
        @boundaries = boundaries
        @locations_by_type_and_field = INTROSPECTION_TYPES.each_with_object(fields) do |type_name, memo|
          introspection_type = schema.get_type(type_name)
          next unless introspection_type.kind.fields?

          memo[type_name] = introspection_type.fields.keys.each_with_object({}) do |field_name, m|
            m[field_name] = [LOCATION]
          end
        end

        @possible_keys_by_type_and_location = {}
        @executables = { LOCATION => @schema }.merge!(executables)
      end

      def fields
        @locations_by_type_and_field.reject { |k, _v| INTROSPECTION_TYPES.include?(k) }
      end

      def export
        return GraphQL::Schema::Printer.print_schema(@schema), {
          "fields" => fields,
          "boundaries" => @boundaries,
        }
      end

      def self.from_export(schema, delegation_map, executables: {})
        schema = GraphQL::Schema.from_definition(schema) if schema.is_a?(String)
        new(
          schema: schema,
          fields: delegation_map["fields"],
          boundaries: delegation_map["boundaries"],
          executables: executables,
        )
      end

      def assign_executable(location, executable = nil, &block)
        executable ||= block
        unless executable.is_a?(Class) && executable <= GraphQL::Schema
          raise StitchingError, "A client or block handler must be provided." unless executable
          raise StitchingError, "A client must be callable" unless executable.respond_to?(:call)
        end
        @executables[location] = executable
      end

      def execute_at_location(location, query, variables, context)
        executable = executables[location]

        if executable.nil?
          raise StitchingError, "No executable assigned for #{location} location."
        elsif executable.is_a?(Class) && executable <= GraphQL::Schema
          executable.execute(
            query: query,
            variables: variables,
            context: context,
            validate: false,
          )
        elsif executable.respond_to?(:call)
          executable.call(location, query, variables, context)
        else
          raise StitchingError, "Missing valid executable for #{location} location."
        end
      end

      # inverts fields map to provide fields for a type/location
      # "Type" => "location" => ["field1", "field2", ...]
      def fields_by_type_and_location
        @fields_by_type_and_location ||= @locations_by_type_and_field.each_with_object({}) do |(type_name, fields), memo|
          memo[type_name] = fields.each_with_object({}) do |(field_name, locations), memo|
            locations.each do |location|
              memo[location] ||= []
              memo[location] << field_name
            end
          end
        end
      end

      # "Type" => ["location1", "location2", ...]
      def locations_by_type
        @locations_by_type ||= @locations_by_type_and_field.each_with_object({}) do |(type_name, fields), memo|
          memo[type_name] = fields.values.flatten.uniq
        end
      end

      # collects possible boundary keys for a given type and location
      # ("Type", "location") => ["id", ...]
      def possible_keys_for_type_and_location(type_name, location)
        possible_keys_by_type = @possible_keys_by_type_and_location[type_name] ||= {}
        possible_keys_by_type[location] ||= begin
          location_fields = fields_by_type_and_location[type_name][location] || []
          location_fields & @boundaries[type_name].map { _1["selection"] }
        end
      end

      # For a given type, route from one origin service to one or more remote locations.
      # Tunes a-star search to favor paths with fewest joining locations, ie:
      # favor longer paths through target locations over shorter paths with additional locations.
      def route_type_to_locations(type_name, start_location, goal_locations)
        results = {}
        costs = {}

        paths = possible_keys_for_type_and_location(type_name, start_location).map do |possible_key|
          [{ location: start_location, selection: possible_key, cost: 0 }]
        end

        while paths.any?
          path = paths.pop
          current_location = path.last[:location]
          current_selection = path.last[:selection]
          current_cost = path.last[:cost]

          @boundaries[type_name].each do |boundary|
            forward_location = boundary["location"]
            next if current_selection != boundary["selection"]
            next if path.any? { _1[:location] == forward_location }

            best_cost = costs[forward_location] || Float::INFINITY
            next if best_cost < current_cost

            path.pop
            path << {
              location: current_location,
              selection: current_selection,
              cost: current_cost,
              boundary: boundary,
            }

            if goal_locations.include?(forward_location)
              current_result = results[forward_location]
              if current_result.nil? || current_cost < best_cost || (current_cost == best_cost && path.length < current_result.length)
                results[forward_location] = path.map { _1[:boundary] }
              end
            else
              path.last[:cost] += 1
            end

            forward_cost = path.last[:cost]
            costs[forward_location] = forward_cost if forward_cost < best_cost

            possible_keys_for_type_and_location(type_name, forward_location).each do |possible_key|
              paths << [*path, { location: forward_location, selection: possible_key, cost: forward_cost }]
            end
          end

          paths.sort! do |a, b|
            cost_diff = a.last[:cost] - b.last[:cost]
            next cost_diff unless cost_diff.zero?
            a.length - b.length
          end.reverse!
        end

        results
      end
    end
  end
end
