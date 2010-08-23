require 'spec_helper'

module Arel
  class EngineProxy
    attr_reader :executed

    def initialize engine
      @engine = engine
      @executed = []
    end

    def connection
      self
    end

    def quote_table_name thing; @engine.connection.quote_table_name thing end
    def quote_column_name thing; @engine.connection.quote_column_name thing end
    def quote thing, column; @engine.connection.quote thing, column end

    def execute sql, name = nil
      @executed << sql
    end
    alias :update :execute
    alias :delete :execute
  end

  describe 'select manager' do
    describe 'order' do
      it 'generates order clauses' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.project SqlLiteral.new '*'
        manager.from table
        manager.order table[:id]
        manager.to_sql.should be_like %{
          SELECT * FROM "users" ORDER BY "users"."id"
        }
      end

      # FIXME: I would like to deprecate this
      it 'takes *args' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.project SqlLiteral.new '*'
        manager.from table
        manager.order table[:id], table[:name]
        manager.to_sql.should be_like %{
          SELECT * FROM "users" ORDER BY "users"."id", "users"."name"
        }
      end

      it 'chains' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        check manager.order(table[:id]).should == manager
      end
    end

    describe 'joins' do
      it 'returns join sql' do
        table   = Table.new :users
        aliaz   = table.alias
        manager = Arel::SelectManager.new Table.engine
        manager.from Nodes::InnerJoin.new(table, aliaz, table[:id].eq(aliaz[:id]))
        manager.join_sql.should be_like %{
          "users" INNER JOIN "users" "users_2" "users"."id" = "users_2"."id"
        }
        check manager.joins(manager).should == manager.join_sql
      end

      it 'returns outer join sql' do
        table   = Table.new :users
        aliaz   = table.alias
        manager = Arel::SelectManager.new Table.engine
        manager.from Nodes::OuterJoin.new(table, aliaz, table[:id].eq(aliaz[:id]))
        manager.join_sql.should be_like %{
          "users" OUTER JOIN "users" "users_2" "users"."id" = "users_2"."id"
        }
        check manager.joins(manager).should == manager.join_sql
      end
    end

    describe 'delete' do
      it "copies from" do
        engine  = EngineProxy.new Table.engine
        table   = Table.new :users
        manager = Arel::SelectManager.new engine
        manager.from table
        manager.delete

        engine.executed.last.should be_like %{ DELETE FROM "users" }
      end

      it "copies where" do
        engine  = EngineProxy.new Table.engine
        table   = Table.new :users
        manager = Arel::SelectManager.new engine
        manager.from table
        manager.where table[:id].eq 10
        manager.delete

        engine.executed.last.should be_like %{
          DELETE FROM "users" WHERE "users"."id" = 10
        }
      end
    end

    describe 'update' do
      it 'takes a string' do
        engine  = EngineProxy.new Table.engine
        table   = Table.new :users
        manager = Arel::SelectManager.new engine
        manager.from table
        manager.update(SqlLiteral.new('foo = bar'))

        engine.executed.last.should be_like %{ UPDATE "users" SET foo = bar }
      end

      it 'copies where clauses' do
        engine  = EngineProxy.new Table.engine
        table   = Table.new :users
        manager = Arel::SelectManager.new engine
        manager.where table[:id].eq 10
        manager.from table
        manager.update(table[:id] => 1)

        engine.executed.last.should be_like %{
          UPDATE "users" SET "id" = 1 WHERE "users"."id" = 10
        }
      end

      it 'executes an update statement' do
        engine  = EngineProxy.new Table.engine
        table   = Table.new :users
        manager = Arel::SelectManager.new engine
        manager.from table
        manager.update(table[:id] => 1)

        engine.executed.last.should be_like %{
          UPDATE "users" SET "id" = 1
        }
      end
    end

    describe 'project' do
      it 'takes strings' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.project Nodes::SqlLiteral.new('*')
        manager.to_sql.should be_like %{
          SELECT *
        }
      end

      it "takes sql literals" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.project Nodes::SqlLiteral.new '*'
        manager.to_sql.should be_like %{
          SELECT *
        }
      end
    end

    describe 'take' do
      it "knows take" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from(table).project(table['id'])
        manager.where(table['id'].eq(1))
        manager.take 1

        manager.to_sql.should be_like %{
          SELECT "users"."id"
          FROM "users"
          WHERE "users"."id" = 1
          LIMIT 1
        }
      end

      it "chains" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.take(1).should == manager
      end
    end

    describe 'where' do
      it "knows where" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from(table).project(table['id'])
        manager.where(table['id'].eq(1))
        manager.to_sql.should be_like %{
          SELECT "users"."id"
          FROM "users"
          WHERE "users"."id" = 1
        }
      end

      it "chains" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from(table)
        manager.project(table['id']).where(table['id'].eq 1).should == manager
      end
    end

    describe "join" do
      it "joins itself" do
        left      = Table.new :users
        right     = left.alias
        predicate = left[:id].eq(right[:id])

        mgr = left.join(right)
        mgr.project Nodes::SqlLiteral.new('*')
        check mgr.on(predicate).should == mgr

        mgr.to_sql.should be_like %{
           SELECT * FROM "users"
             INNER JOIN "users" "users_2"
               ON "users"."id" = "users_2"."id"
        }
      end
    end

    describe 'from' do
      it "makes sql" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine

        manager.from table
        manager.project table['id']
        manager.to_sql.should be_like 'SELECT "users"."id" FROM "users"'
      end

      it "chains" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        check manager.from(table).project(table['id']).should == manager
        manager.to_sql.should be_like 'SELECT "users"."id" FROM "users"'
      end
    end

    describe "TreeManager" do
      subject do
        table   = Table.new :users
        Arel::SelectManager.new(Table.engine).tap do |manager|
          manager.from(table).project(table['id'])
        end
      end

      it_should_behave_like "TreeManager"
    end
  end
end
