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


# Export in MapInfo format
ogr2ogr -f "MapInfo file" $OUTPATH/strade.tab $OUTPATH/milano_raw.sqlite strade


# Do some Basic reporting
echo ""
echo ""
echo "Download: $NOW - number of ways with highway tag:" >> download.log

ogrinfo -sql "select sum(loc_ref is null), sum(loc_ref = -1), sum(loc_ref <> -1) from strade" $OUTPATH/milano_raw.sqlite | tail -n 4 | sed -e 's/(Integer) //g' >> download.log


