# frozen_string_literal: true

module GraphQL
  module Stitching
    # Defines a boundary query that provides direct access to an entity type.
    Boundary = Struct.new(
      :location,
      :type_name,
      :keys,
      :field,
      :args,
      :list,
      :federation,
      keyword_init: true
    ) do
      def as_json
        {
          location: location,
          type_name: type_name,
          keys: keys,
          field: field,
          args: args,
          list: list,
          federation: federation,
        }.tap(&:compact!)
      end
    end
  end
end
