# osmraw2sfs

This tool makes an OSM raw spatialite db viewable with QGIS and other OGR SFS compliant GIS.

It has two main features:

* Creates sfs geometry in a given projection for ways and nodes
* Creates / drops spatial views based on the [node|way]-tag relationship.

An overview of the entire process:


```
# First, download an OSM file
wget -O milano.osm http://overpass-api.de/api/map?bbox=9.06,45.37,9.28,45.56


# Then, load it into a spatialite DB:
spatialite_osm_raw -jo -o milano.osm -d milano_raw.sqlite

# Initialize the DB: create geometries 
python osmraw2sfs.py milano_raw.sqlite initdb

# Create the views
python osmraw2sfs.py milano_raw.sqlite createview wayrailway

```


Views can be defined using ini files (located in the views subfolder), according to the following model:

```
# exampleview.ini
# Example of raw osm db view definition

# Name of the view in the database
view_name=streets

description=long (however long a single line may be) description 

# OSM primitive class: way|node
geom_class=way

# List of tags that will be joined to the primitive and returned in the view as fields
# key-tags (required tags) will be joined with an INNER join
# non-key (optional) tags will be joined with a LEFT join
# tags=key_tag*,key_tag*,optional_tag,optional_tag,...
tags=highway*,name,oneway,lanes,access

# Meta fields (version, user id...) are expected to be in osm_ways, osm_nodes and osm_relations tables
# Be sure to download them from overpass specifying <print mode="meta"/>
meta=version,timestamp,uid,user,changeset

# where condition in sqlite SQL
# tags names become field names
where=highway != 'steps' and highway != 'footway' 

```

The tool is released under GPL - See LICENSE.md for details.

I took some inspiration from the [spatialite cookbook](http://www.gaia-gis.it/gaia-sins/spatialite-cookbook/html/python.html). Thanks to Alessandro Furieri for the great job with spatialite.


