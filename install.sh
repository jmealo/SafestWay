#!/bin/bash
cat <<HEADER
     _______.     ___       _______  _______     _______.___________.
    /       |    /   \     |   ____||   ____|   /       |           |
   |   (----'   /  ^  \    |  |__   |  |__     |   (----'---|  |----'
    \   \      /  /_\  \   |   __|  |   __|     \   \       |  |
.----)   |    /  _____  \  |  |     |  |____.----)   |      |  |
|_______/    /__/     \__\ |__|     |_______|_______/       |__|

____    __    ____  ___   ____    ____
\   \  /  \  /   / /   \  \   \  /   /
 \   \/    \/   / /  ^  \  \   \/   /
  \            / /  /_\  \  \_    _/
   \    /\    / /  _____  \   |  |
    \__/  \__/ /__/     \__\  |__|
-------------------------------------------------------------------------------
| Installer (Alpha) |  Root access may be required; see comments for details. |
-------------------------------------------------------------------------------

HEADER

#OSX Specific
if [[ $OSTYPE == "darwin"* ]]
then
cat <<NOTICE
*******************************************************************************
OSX has low limits on the number of open sockets and files. We need to increase
them to process data in parallel. (THIS REQUIRES ROOT ACCESS) If you don't know
your root password, visit: http://support.apple.com/kb/ht1528
*******************************************************************************
NOTICE
    read -p "Would you like to adjust the kernel parameters as needed? [y/n]" -n 1
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        echo ""
        sudo sysctl -w kern.maxfiles=1048600
        sudo sysctl -w kern.maxfilesperproc=1048576
        sudo ulimit -n 1048576
    else
        echo ""
        echo "Continuing begrudgingly... you may run into problems."
    fi
fi

#OSMOSIS
if [[ `perl -e 'print ((qx(osmosis --v 2>&1) =~ m/INFO:\sOsmosis\sVersion\s0.(4[2-9]|[5-9][0-9])/m) ? 0:1)'` == 1 ]]
then
    read -p "Osmosis 0.42+ is required. Install the latest version? [y/n]" -n 1
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        sudo apt-get -y install openjdk-6-jdk git
            git clone https://github.com/openstreetmap/osmosis.git
            cd osmosis
            ./gradlew assemble
            unzip -uo package/build/distribution/*.zip -d /usr
            chmod +x /usr/bin/osmosis
    else
        echo "Exiting installer"
        exit 1
    fi
fi

#OGR2OGR (GDAL)
if [[ ! `ogr2ogr --help` == "Usage"* ]]
then
    if [[ -e /etc/debian_version ]]
    then
        read -p "GDAL is required for ogr2ogr. Install the latest version? [y/n]" -n 1
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            sudo apt-get -y install gdal-bin
        else
            echo "Exiting installer"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]
    then
        read -p "GDAL is required for ogr2ogr. Install the latest version? [y/n]" -n 1
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            curl -S http://www.kyngchaos.com/files/software/frameworks/GDAL_Complete-1.9.dmg > GDAL_Complete-1.9.dmg
            hdiutil mount GDAL_Complete-1.9.dmg
            target_volume=`perl -e '\`diskutil list /\` =~ m/Apple_HFS\s(.*)/m;@a=split(/\s{2,}/, $1);print ($a[0])'`
            sudo installer -package "/Volumes/GDAL Complete/GDAL Complete.pkg" -target "/Volumes/$target_volume"
            sudo ln -s /Library/Frameworks/GDAL.framework/Versions/1.9/Programs/ogr2ogr /usr/bin
        else
            echo "Exiting installer"
            exit 1
        fi

    if [[ ! `ogr2ogr --help` == "Usage"* ]]
    then
        echo "GDAL Install failed; exiting"
        exit 1
    fi

    else
        echo "ogr2ogr (GDAL) is required. Please install and re-run this script."
        exit 1
    fi
fi

#Python GDAL (the OSX package includes this... I think)
if [[ -e /etc/debian_version ]]
then
    sudo apt-get -y install python-gdal
fi

#OSMFILTER - used to strip the .osm file down to just what we need for routing
echo "Downloading and building osmfilter..."
curl http://m.m.i24.cc/osmfilter.c |cc -x c - -O3 -o osmfilter

#most city extracts are bounding box; we'll use the shape file to trim to the city likmits
curl -S http://www.pasda.psu.edu/philacity/data/phila-city_limits_shp.zip > phila-city_limits_shp.zip
unzip -uo phila-city_limits_shp.zip

#convert to the correct coordinate system
ogr2ogr -t_srs EPSG:4326 -a_srs EPSG:4326 philly.shp city_limits.shp

#convert the city limits shape file to a .poly file so we can filter our OSM extract
curl -S https://trac.openstreetmap.org/export/29520/subversion/applications/utils/osm-extract/polygons/ogr2poly.py > ogr2poly.py
python ogr2poly.py philly.shp

curl -S http://osm-extracted-metros.s3.amazonaws.com/philadelphia.osm.pbf > philadelphia.osm.pbf

#trim OSM extract to philly limits
osmosis --read-bin file="philadelphia.osm.pbf" --bounding-polygon file="philly_0.poly" --write-bin file="philly.osm.pbf"

#remove nodes that aren't part of the road network
osmosis --read-bin philly.osm.pbf --way-key keyList="highway" --used-node --write-xml philadelphia.osm

#drop author information, versions, and relations [we can't do this first; because osmfilter doesn't do .osm.pbf]
./osmfilter philadelphia.osm --drop-relations --drop-author --drop-version -o=philly.osm

curl -S http://www.pasda.psu.edu/philacity/data/PhiladelphiaCensusBlockGroups201201.zip > PhiladelphiaCensusBlockGroups201201.zip
unzip -uo PhiladelphiaCensusBlockGroups201201.zip

ogr2ogr -F GeoJSON -skip-failures -t_srs EPSG:4326 -a_srs EPSG:4326 census_block_groups.json "Philadelphia Census Block Groups/PhiladelphiaCensusBlockGroups201201.shp"

git clone git://github.com/azavea/geo-data.git
ogr2ogr -F GeoJSON -skip-failures -t_srs EPSG:4326 -a_srs EPSG:4326 philly_neighborhoods.json geo-data/Neighborhoods_Philadelphia/Neighborhoods_Philadelphia.shp

curl -S http://www2.census.gov/geo/tiger/TIGER2010BLKPOPHU/tabblock2010_42_pophu.zip > tabblock2010_42_pophu.zip
unzip -uo tabblock2010_42_pophu.zip

ogr2ogr -F GeoJSON -skip-failures -where "COUNTYFP10='101'" tabblock2010_42_pophu.json tabblock2010_42_pophu.shp
#extract population and housing units for Philadelphia county only

#cleanup
rm philadelphia.osm.pbf
rm philadelphia.osm

curl -S http://gis.phila.gov/data/police_inct.zip > police_inct.zip
unzip -uo police_inct.zip
