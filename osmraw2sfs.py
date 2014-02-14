#! /usr/bin/python

# (C) 2014 Luca S. Percich
# Released under GPL - See LICENSE.md

from pyspatialite import dbapi2 as db

import sys
import os.path

class OSMRawDB(object):
    
    sql_echo = False
    
    def __init__(self, dbpath, SRID=3003):
        self.SRID = SRID
        self.database_path = dbpath
        self.connection = db.connect(self.database_path)


    def init_db_struct(self):
        print "Adding indexes and geometry fields to nodes and ways..."
        self.execute(
            "select AddGeometryColumn('osm_nodes', 'geom', %s, 'POINT', 2)" % self.SRID,
            "update osm_nodes set geom = transform(Geometry, %s)" % self.SRID,
            "select CreateSpatialIndex('osm_nodes', 'geom')",
            "select AddGeometryColumn('osm_ways', 'geom', %s, 'LINESTRING', 2)" % self.SRID,
            "select CreateSpatialIndex('osm_ways', 'geom')"
        )
        self.connection.commit()


    def execute(self, *statements, **options):
        cursor = self.connection.cursor()
        echo = options.get('sql_echo', self.sql_echo)
        for statement in statements:
            if echo:
                print statement
            cursor.execute(statement)
        self.connection.commit()
        cursor.close()
        
        
    def update_way_geometry(self):
        Way.cursor = self.connection.cursor()
        Way.SRID = self.SRID
        cur = self.connection.cursor()
        rs = cur.execute("""
            SELECT w.way_id, w.sub, x(n.geom) as x, y(n.geom) as y
            from osm_way_refs w left join osm_nodes n 
                on w.node_id = n.node_id 
            order by way_id, sub
            """)
        ct = 0
        for (wid, sub, x, y) in rs:
            Way.add_way(wid, x, y)
            ct += 1
            if ct % 50000 == 0:
                print "%s ways..." % ct
        Way.close()

        self.connection.commit()
        Way.cursor.close()
    
    
    def close(self):
        self.connection.close()
        
        
    def create_view(self, view):
        rv = self.get_view(view)
        rv.drop()
        rv.create()
        
        
    def drop_view(self, view):
        rv = self.get_view(view)
        rv.drop()
        
        
    def get_view(self, view):
        return RawView(view, self)
        
        

class Way(object):
    
    way = None
    cursor = None
    SRID = 3003
    
    @classmethod
    def add_way(cls, id, x, y):
        if not cls.way:
            cls.way = Way(id)
        if cls.way.id != id:
            cls.way.send_out()
            cls.way = Way(id)
        if id:
            cls.way.add_point(x, y)
            
    @classmethod
    def close(cls):
        cls.add_way(0,0,0)
            
    def __init__(self, id):
        self.id = id
        self.coords =[]
        
    def add_point(self, x, y):
        self.coords.append((x, y))
        
    def as_text(self):
        return 'LINESTRING(' + ', '.join(["%s %s" % (x, y) for (x, y) in self.coords]) + ')'
        
    def send_out(self):
        if len(self.coords):
            sql = "update osm_ways set geom = geomfromtext('%s', %s) where way_id = %s" % (self.as_text(), self.SRID, self.id)
        elif self.id:
            sql = "update osm_ways set geom = Null where way_id = %s" % self.id
        self.cursor.execute(sql)
        
        
class RawView(object):
    
    def __init__(self, name, db):
        self.name = name
        self.db = db
        self.filename = self.build_ini_filename()
        self.load_from_ini(self.filename)
        
        
    def build_ini_filename(self):
        return os.path.join(os.path.abspath(os.path.dirname(__file__)), 'views', self.name + '.ini')
        
        
    def load_from_ini(self, filename):
        print "Loading view from file: " + filename
        try:
            config = self.read_config(filename)
            self.view_name=config.get('name', self.name)
            self.description=config.get('description', '')
            self.geom_class=config['geom_class']
            if self.geom_class == 'way':
                self.geom_table='osm_ways'
                self.tags_table = 'osm_way_tags'
                self.tags_fk = 'way_id'
            elif self.geom_class == 'node':
                self.geom_table='osm_nodes'
                self.tags_table = 'osm_node_tags'
                self.tags_fk = 'node_id'
                
            self.tags = config['tags']
            if self.tags.__class__ == str:
                self.tags = self.tags.split(',')
            self.tags = filter(None, self.tags)
            if self.tags == []:
                raise Exception('Specify at least one tag in the tags= property')
            self.where = config.get('where', '')
            self.build_sql()
        except Exception, e:
            print "Unable to read view configuration file {file}.".format(file=filename)
            raise
            
            
    def read_config(self, filename):
        f = open(filename)
        config = {}
        for line in f:
            line = line.strip()
            if line and line[0] != '#':
                (key, value) = line.split('=', 1)
                config[key] = value
        f.close()
        return config

            
    def build_sql(self):
        fields = []
        joins = []
        field_list = []
        for field_raw in self.tags:
            if field_raw[-1] == '*':
                join_type = 'inner'
                field_raw = field_raw[:-1]
            else:
                join_type = 'left'
            field = field_raw.replace(':','__')
            fields.append('{field}.v as {field}'.format(field=field))
            join_tpl = "{join_type} join {tags} as {field} on {table}.{tag_id} = {field}.{tag_id} and {field}.k = '{field_raw}'"
            joins.append(join_tpl.format(tags=self.tags_table, tag_id=self.tags_fk, field=field, join_type=join_type, field_raw=field_raw, table=self.geom_table))
            field_list.append(field)
        sql = 'select {table}.{fk}, {table}.ROWID as rowid, {table}.geom, {fields} from {table} {joins}'.format(fk=self.tags_fk, fields=','.join(fields),table=self.geom_table,joins=' '.join(joins))
        if self.where:
            sql = 'select {fk}, rowid, geom, {fields} from ({sql}) as q where ({where})'.format(fk=self.tags_fk,  fields=','.join(field_list),sql=sql, where=self.where)
        return sql
        
        
    def create(self):
        sql = self.build_sql()
        print "Creating view %s..." % self.view_name
        self.db.execute(
            "create view %s as %s" % (self.view_name, sql),
            "insert into views_geometry_columns (view_name, view_geometry, view_rowid, f_table_name, f_geometry_column, read_only) values ('%s', '%s', '%s', '%s', '%s', %s)" % (self.view_name, 'geom', 'rowid', self.geom_table, 'geom', 1),
        )
        
        
    def drop(self):
        print "Dropping view %s..." % self.view_name
        self.db.execute(
            'drop view if exists %s' % self.view_name,
            "delete from views_geometry_columns where view_name = '%s'" % self.view_name,
        )
        
        
if __name__ == '__main__':
    try:
        db_path = sys.argv[1]
        command = sys.argv[2]
        if command in ['createview', 'dropview']:
            views = sys.argv[3:]
    except IndexError:
        print "usage: raw2sfs <dbpath.sqlite> <command>"
        print "   command:  initdb"
        print "   command:  createview <view_name> [<view_name>...]"
        print "   command:  dropview <view_name>  [<view_name>...]"
        quit()

    try:
        osmdb = OSMRawDB(db_path)
        if command == 'initdb':
            osmdb.init_db_struct()
            osmdb.update_way_geometry()
        elif command == 'createview':
            for view in views:
                osmdb.create_view(view)
        elif command == 'dropview':
            for view in views:
                osmdb.drop_view(view)
            
        osmdb.close()
    except Exception, e:
        print "Error processing DB " + db_path
        print str(e)
