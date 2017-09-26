# Core

**C**rystal **O**bject **RE**lational Mapping you've been waiting for.

[![Build Status](https://travis-ci.org/vladfaust/core.cr.svg?branch=master)](https://travis-ci.org/vladfaust/core.cr) [![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://vladfaust.com/core.cr) [![Dependency Status](https://shards.rocks/badge/github/vladfaust/core.cr/status.svg)](https://shards.rocks/github/vladfaust/core.cr) [![GitHub release](https://img.shields.io/github/release/vladfaust/core.cr.svg)](https://github.com/vladfaust/core.cr/releases)

## About

Tired of [ActiveRecord](https://wikipedia.org/wiki/Active_record_pattern)'s magic? Forget it. It's time for real programming!

**Core** is inspired by [Crecto](https://github.com/Crecto/crecto) but more transparent and Crystal-ish.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  core:
    github: vladfaust/core.cr
    version: ~> 0.1.0
```

## Usage

Assuming following initial database migration:

```sql
CREATE TABLE users(
  id          SERIAL PRIMARY KEY,
  name        VARCHAR(100)  NOT NULL,
  created_at  TIMESTAMPTZ   NOT NULL,
  updated_at  TIMESTAMPTZ
);

CREATE TABLE posts(
  id          SERIAL PRIMARY KEY,
  author_id   INT         NOT NULL  REFERENCES users (id),
  content     TEXT        NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL,
  updated_at  TIMESTAMPTZ
);
```

```crystal
require "core"
require "db"
require "pg" # Or another driver

class User < Core::Model
  schema do
    primary_key :id
    field :name, String
    virtual_field :posts_count, Int64
    reference :posts, Array(Post), foreign_key: :author_id
    created_at_field :created_at
    updated_at_field :updated_at
  end

  validation do
    errors.push({:name => "length must be >= 3"}) unless name.try &.size.>= 3
  end
end

class Post < Core::Model
  schema do
    primary_key :id
    field :content, String
    reference :author, User, key: :author_id
    created_at_field :created_at
    updated_at_field :updated_at
  end
end

db = DB.open(ENV["DATABASE_URL"])
query_logger = Core::QueryLogger.new(STDOUT)

user_repo = Core::Repository(User).new(db, query_logger)
post_repo = Core::Repository(Post).new(db, query_logger)

user = User.new(name: "Fo")
user.valid? # => false
user.errors # => [{:name => "length must be >= 3"}]
user.name = "Foo"
user.valid? # => true

user.id = user_repo.insert(user) # See ^1
# INSERT INTO users (name, created_at) VALUES ($1, $2) RETURNING id

post = Post.new(author: user, content: "Foo Bar")
post.id = post_repo.insert(post) # See ^1
# INSERT INTO posts (author_id, content, created_at) VALUES ($1, $2, $3) RETURNING id

alias Query = Core::Query

posts = post_repo.query(Query(Post).where(author: user))
# SELECT * FROM posts WHERE author_id = $1

posts.first.content # => "Foo Bar"

query = Query(User)
  .join(:posts)
  .select(:*, :"COUNT(posts.id) AS posts_count")
  .group_by(%i(users.id posts.id))
  .one
user = user_repo.query(query).first
# SELECT *, COUNT (posts.id) AS posts_count
# FROM users JOIN posts AS posts ON posts.author_id = users.id
# GROUP BY users.id, posts.id LIMIT 1

user.posts_count # => 1

user.name = "Bar"
user.changes # => {:name => "Bar"}
user_repo.update(user)
# UPDATE users SET name = $1 WHERE id = $2 RETURNING id

post_repo.delete(posts.first)
# DELETE FROM posts WHERE id = $1
```

**^1:** Returning IDs is not working for PostgreSQL yet. See https://github.com/will/crystal-pg/issues/112.

## Contributing

1. Fork it ( https://github.com/vladfaust/core.cr/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [@vladfaust](https://github.com/vladfaust) Vlad Faust - creator, maintainer
