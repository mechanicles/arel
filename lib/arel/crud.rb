module Arel
  ###
  # FIXME hopefully we can remove this
  module Crud
    # FIXME: this method should go away
    def update values
      um = UpdateManager.new @engine

      if Nodes::SqlLiteral === values
        um.table @ctx.froms.last
      else
        um.table values.first.first.relation
      end
      um.set values
      um.wheres = @ctx.wheres
      @engine.connection.update um.to_sql, 'AREL'
    end

    # FIXME: this method should go away
    def insert values
      im = InsertManager.new @engine
      im.insert values
      @engine.connection.insert im.to_sql
    end

    def delete
      dm = DeleteManager.new @engine
      dm.wheres = @ctx.wheres
      dm.from @ctx.froms.last
      @engine.connection.delete dm.to_sql, 'AREL'
    end
  end
end
