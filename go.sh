# First, download an OSM file


OUTPATH=out

NOW=$(date +%Y%m%d-%H%M%S)

tar cfz data_$NOW.tgz $OUTPATH/
 
rm $OUTPATH/*.*

# Download data for Milano
#~ wget -O $OUTPATH/milano.osm "http://overpass-api.de/api/interpreter?data=%3Cosm-script%20output%3D%22xml%22%20timeout%3D%2225%22%3E%20%20%0A%20%20%3Cid-query%20type%3D%22area%22%20ref%3D%223600044915%22%20into%3D%22area%22%2F%3E%0A%20%20%3C%21--%20gather%20results%20--%3E%0A%20%20%3Cunion%3E%0A%20%20%20%20%3Cquery%20type%3D%22way%22%3E%0A%20%20%20%20%20%20%3Carea-query%20from%3D%22area%22%2F%3E%0A%20%20%20%20%3C%2Fquery%3E%0A%20%20%20%20%3Cquery%20type%3D%22node%22%3E%0A%20%20%20%20%20%20%3Carea-query%20from%3D%22area%22%2F%3E%0A%20%20%20%20%3C%2Fquery%3E%0A%20%20%20%20%3Cquery%20type%3D%22relation%22%3E%0A%20%20%20%20%20%20%3Carea-query%20from%3D%22area%22%2F%3E%0A%20%20%20%20%3C%2Fquery%3E%0A%20%20%3C%2Funion%3E%0A%20%20%3C%21--%20print%20results%20--%3E%0A%20%20%3Cprint%20mode%3D%22body%22%2F%3E%0A%20%20%3Crecurse%20type%3D%22down%22%2F%3E%0A%20%20%3Cprint%20mode%3D%22skeleton%22%20order%3D%22quadtile%22%2F%3E%0A%3C%2Fosm-script%3E"
wget -O $OUTPATH/milano.osm "http://overpass-api.de/api/interpreter?data=%3Cosm-script%20output%3D%22xml%22%20timeout%3D%2225%22%3E%20%20%0A%20%20%3Cid-query%20type%3D%22area%22%20ref%3D%223600044915%22%20into%3D%22area%22%2F%3E%0A%20%20%3C%21--%20gather%20results%20--%3E%0A%20%20%3Cunion%3E%0A%20%20%20%20%3Cquery%20type%3D%22way%22%3E%0A%20%20%20%20%20%20%3Carea-query%20from%3D%22area%22%2F%3E%0A%20%20%20%20%3C%2Fquery%3E%0A%20%20%20%20%3Cquery%20type%3D%22node%22%3E%0A%20%20%20%20%20%20%3Carea-query%20from%3D%22area%22%2F%3E%0A%20%20%20%20%3C%2Fquery%3E%0A%20%20%20%20%3Cquery%20type%3D%22relation%22%3E%0A%20%20%20%20%20%20%3Carea-query%20from%3D%22area%22%2F%3E%0A%20%20%20%20%3C%2Fquery%3E%0A%20%20%3C%2Funion%3E%0A%20%20%3C%21--%20print%20results%20--%3E%0A%20%20%3Cprint%20mode%3D%22meta%22%2F%3E%0A%20%20%3Crecurse%20type%3D%22down%22%2F%3E%0A%3C%2Fosm-script%3E"


# Then, load it into a spatialite DB:
spatialite_osm_raw -jo -o $OUTPATH/milano.osm -d $OUTPATH/milano_raw.sqlite


# Initialize the DB: create geometries 
python osmraw2sfs.py $OUTPATH/milano_raw.sqlite initdb


# Finally, create the views
python osmraw2sfs.py $OUTPATH/milano_raw.sqlite createview highwaytags railwaytags strade wayrailway locref


# Create temp table for AMAT graph
python osmraw2sfs.py $OUTPATH/milano_raw.sqlite execute "CREATE TABLE 'elemstr_in' ('id' INTEGER, 'carr_sensomarcia' INTEGER, 'carr_numcarreggiate' INTEGER, 'carr_largdx' FLOAT, 'carr_largsn' FLOAT, 'carr_corsiedx' INTEGER, 'carr_corsiesn' INTEGER, 'carr_corsietpldx' INTEGER, 'carr_corsietplsn' INTEGER, 'carr_tpldx_cod' INTEGER, 'carr_tplsn_cod' INTEGER, 'carr_limdx_cod' INTEGER, 'carr_limsn_cod' INTEGER, 'carr_divtrans_cod' INTEGER, 'carr_tramdx' INTEGER, 'carr_tramsn' INTEGER, 'lunghezza' FLOAT, 'comeg3' VARCHAR(1), 'precdx_cod' INTEGER, 'precsn_cod' INTEGER, 'sottopasso' VARCHAR(1), 'tipo_cod' VARCHAR(16), 'via_id' INTEGER, 'nodoorigine_id' INTEGER, 'nododestinazione_id' INTEGER, 'largclasse_cod' VARCHAR(2), 'tronco_id' INTEGER, 'troncorel_proginizio' FLOAT, 'troncorel_progfine' FLOAT, 'troncorel_lato' INTEGER, 'troncorel_distanza' FLOAT, 'classefunz_cod' VARCHAR(2), 'attuazionepgtu' VARCHAR(40), 'classepgtuprog_cod' VARCHAR(16), 'classepgtu_cod' VARCHAR(16), 'enteproprietario_cod' VARCHAR(2), 'stato_cod' VARCHAR(2), 'classificaamm_cod' VARCHAR(2), 'edit_autore' VARCHAR(16), 'edit_istcreazione' VARCHAR(40), 'edit_istmodifica' VARCHAR(40))"
python osmraw2sfs.py $OUTPATH/milano_raw.sqlite execute "select addgeometrycolumn('elemstr_in', 'geom', 3003, 'LINESTRING', 'XY')"

# Load AMAT road network into spatialite
ogr2ogr -append -update -lco GEOMETRY_NAME=geom -f "SQLite" $OUTPATH/milano_raw.sqlite /home/sigfrido/D/AMAT/SIS/DEV_LOCAL/ElementoStradale.TAB -nln elemstr_in

# Create temp table for AMAT graph
python osmraw2sfs.py $OUTPATH/milano_raw.sqlite execute "CREATE TABLE 'elemstr' ('id' INTEGER primary key, 'carr_sensomarcia' INTEGER, 'carr_numcarreggiate' INTEGER, 'carr_largdx' FLOAT, 'carr_largsn' FLOAT, 'carr_corsiedx' INTEGER, 'carr_corsiesn' INTEGER, 'carr_corsietpldx' INTEGER, 'carr_corsietplsn' INTEGER, 'carr_tpldx_cod' INTEGER, 'carr_tplsn_cod' INTEGER, 'carr_limdx_cod' INTEGER, 'carr_limsn_cod' INTEGER, 'carr_divtrans_cod' INTEGER, 'carr_tramdx' INTEGER, 'carr_tramsn' INTEGER, 'lunghezza' FLOAT, 'comeg3' VARCHAR(1), 'precdx_cod' INTEGER, 'precsn_cod' INTEGER, 'sottopasso' VARCHAR(1), 'tipo_cod' VARCHAR(16), 'via_id' INTEGER, 'nodoorigine_id' INTEGER, 'nododestinazione_id' INTEGER, 'largclasse_cod' VARCHAR(2), 'tronco_id' INTEGER, 'troncorel_proginizio' FLOAT, 'troncorel_progfine' FLOAT, 'troncorel_lato' INTEGER, 'troncorel_distanza' FLOAT, 'classefunz_cod' VARCHAR(2), 'attuazionepgtu' VARCHAR(40), 'classepgtuprog_cod' VARCHAR(16), 'classepgtu_cod' VARCHAR(16), 'enteproprietario_cod' VARCHAR(2), 'stato_cod' VARCHAR(2), 'classificaamm_cod' VARCHAR(2), 'edit_autore' VARCHAR(16), 'edit_istcreazione' VARCHAR(40), 'edit_istmodifica' VARCHAR(40))"
python osmraw2sfs.py $OUTPATH/milano_raw.sqlite execute "select addgeometrycolumn('elemstr', 'geom', 3003, 'LINESTRING', 'XY')"
python osmraw2sfs.py $OUTPATH/milano_raw.sqlite execute "insert into 'elemstr' select * from elemstr_in" "drop table elemstr_in" "select CreateSpatialIndex('elemstr', 'geom')"


# Export in MapInfo format
ogr2ogr -f "MapInfo file" $OUTPATH/strade.tab $OUTPATH/milano_raw.sqlite strade


# Do some Basic reporting
echo ""
echo ""
echo "Download: $NOW - number of ways with highway tag:" >> download.log

ogrinfo -sql "select sum(loc_ref is null), sum(loc_ref = -1), sum(loc_ref <> -1) from strade" $OUTPATH/milano_raw.sqlite | tail -n 4 | sed -e 's/(Integer) //g' >> download.log


