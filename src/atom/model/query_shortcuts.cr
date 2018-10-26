class Atom
  module Model
    private macro define_query_shortcuts
      def self.query
        Atom::Query(self).new
      end

      {% for method in %w(group_by having insert limit offset set where) %}
        # Create new `Atom::Query` and call {{method}} on it.
        def self.{{method.id}}(*args, **nargs)
          query.{{method.id}}(*args, **nargs)
        end
      {% end %}

      {% for method in %w(update delete all one first last) %}
        def self.{{method.id}}
          query.{{method.id}}
        end
      {% end %}

      def self.join(table : String, on : String, *, type _type : Atom::Query::JoinType = :inner, as _as : String | Nil = nil)
        query.join(table, on, type: _type, as: _as)
      end

      def self.join(reference : Reference, *, type _type : Atom::Query::JoinType = :inner, **options)
        query.join(reference, **options, type: _type)
      end

      def self.order_by(value : Attribute | String, order : Atom::Query::Order | Nil = nil)
        query.order_by(value, order)
      end

      def self.returning(*values : Attribute | String | Char)
        query.returning(*values)
      end

      def self.select(*values : self.class | Attribute | String | Char)
        query.select(*values)
      end

      # Create an insert `Atom::Query` for this instance.
      #
      # ```
      # User.new(name: "John").insert.to_s # INSERT INTO users (name) VALUES (?)
      # ```
      def insert
        self.class.query.insert(
          {% for type in MODEL_ATTRIBUTES + MODEL_REFERENCES.select(&.["direct"]) %}
            {{type["name"]}}: @{{type["name"]}}{{".not_nil!".id unless type["db_nilable"]}},
          {% end %}
        )
      end

      # Create an update `Atom::Query` for this instance.
      #
      # ```
      # user.name = "Jake"
      # user.update.to_s # UPDATE users SET name = ? WHERE uuid = ?
      # ```
      def update
        raise ArgumentError.new("No changes to update") if changes.empty?

        q = self.class.query.update

        {% for type in MODEL_ATTRIBUTES + MODEL_REFERENCES.select(&.["direct"]) %}
          if changes.has_key?({{type["name"].stringify}})
            q.set({{type["name"]}}: changes[{{type["name"].stringify}}].as({{type["true_type"]}}{{" | DB::Default.class".id if type["db_default"]}}{{" | ::Nil".id if type["db_nilable"]}}))
          end
        {% end %}

        q.where({{MODEL_PRIMARY_KEY}}: primary_key)
      end

      # Create a deletion `Atom::Query` for this instance.
      #
      # ```
      # user.delete.to_s # DELETE FROM users WHERE uuid = ?
      # ```
      def delete
        self.class.query.delete.where({{MODEL_PRIMARY_KEY}}: primary_key)
      end
    end
  end
end