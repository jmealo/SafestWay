#!/usr/bin/env bash
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

# Determine OS
if [[ -e /etc/debian_version ]]; then OS="debian" ; fi
if [[ $OSTYPE == "darwin"*   ]]; then OS="osx"    ; fi
if [[ $OSTYPE == "solaris"*  ]]; then OS="smartos"; fi
if [[ $OSTYPE == "FreeBSD"*  ]]; then OS="freebsd"; fi

if [[ $OS == "smartos" ]]; then
    NUM_OF_CPUS=`kstat cpu_info|grep core_id|sort -u|wc -l`
else
    NUM_OF_CPUS=`grep -c ^processor /proc/cpuinfo 2> /dev/null || sysctl hw.ncpu | awk '{print $2}' 2> /dev/null`
fi

function is_missing () {
    ! hash "$1" &> /dev/null ;
}

#OSX Specific
if [[ $OS == "osx" ]]; then
cat <<NOTICE
*******************************************************************************
OSX has low limits on the number of open sockets and files. We need to increase
them to process data in parallel. (THIS REQUIRES ROOT ACCESS) If you don't know
your root password, visit: http://support.apple.com/kb/ht1528
*******************************************************************************

Please follow any dialogs that appear regarding XCode and the Java JDK.

NOTICE

    read -p "$(echo -e '\n\bWould you like to adjust the kernel parameters as needed? [y/n]\n\b')" -n 1
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        sudo sysctl -w kern.maxfiles=1048600
        sudo sysctl -w kern.maxfilesperproc=1048576
        sudo ulimit -n 1048576
    else
        echo ""
        echo "Continuing begrudgingly... you may run into problems."
    fi

    #check for Xcode and command line tools or a third-party GCC/clang
    if is_missing gcc || [[ `gcc 2>&1` == *"xcode"* ]]; then
        if [[ ! `xcode-select -v` == "xcode-select version"* ]]; then
            echo "You must install Xcode before continuing... you can get it for free in the App Store:"
            echo "https://itunes.apple.com/us/app/xcode/id497799835"
        else
            echo "The Xcode 'Command Line Tools' package is missing, here are instructions for installing it:"
            echo "http://goo.gl/XFVcY3"
        fi
        exit 1
    fi
fi




#TODO: do this on first run only...
if [[ $OS == "debian" ]]; then
    sudo apt-get update -y
elif [[ $OS == "smartos" ]]; then
    sudo pkgin -y update
fi

if is_missing wget ; then
    if [[ $OS == "osx" ]]; then
        wget -N -c http://ftp.gnu.org/gnu/wget/wget-1.15.tar.gz
        tar -xzvf wget-1.15.tar.gz
        cd wget-1.15
        ./configure --with-ssl=openssl
        make -j {$NUM_OF_CPUS}
        sudo make install
    elif [[ $OS == "debian" ]]; then
        sudo apt-get install wget
    elif [[ $OS == "smartos" ]]; then
        sudo pkgin -y in wget
    elif [[ $OS == "freebsd" ]]; then
        sudo pkg_add -v -r wget
    fi
fi

if is_missing gcc ; then
    if [[ $OS == "debian" ]]
        then
        read -p "$(echo -e '\n\bA compiler is required. Install the build-essential package? [y/n]\n\b')" -n 1
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            sudo apt-get -y install build-essential
        else
            echo "Exiting installer"
            exit 1
        fi
    elif [[ $OS == "smartos" ]]
        then
        pkgin -y in gcc47
    fi
fi

if is_missing unzip ; then
    echo "Installing unzip..."
    if [[ $OS == "debian" ]]
        then
        sudo apt-get -y install unzip
    elif [[ $OS == "smartos" ]]
        then
        pkgin -y in unzip
    fi
fi

function install_java {
    if is_missing java ; then
            read -p "$(echo -e '\n\bJava is required. Install the Java package? [y/n]\n\b')" -n 1
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if [[ $OS == 'debian' ]]; then
                    sudo apt-get -y install openjdk-6-jre-headless
                elif [[ $OS == 'osx' ]]; then
                    wget -N -c http://support.apple.com/downloads/DL1572/en_US/JavaForOSX2013-05.dmg
                    hdiutil mount JavaForOSX2013-05.dmg
                    target_volume=`perl -e '\`diskutil list /\` =~ m/Apple_HFS\s(.*)/m;@a=split(/\s{2,}/, $1);print ($a[0])'`
                    sudo installer -package \
                        "/Volumes/Java for OS X 2013-005/JavaForOSX.pkg" \
                        -target "/Volumes/$target_volume"
                    source /etc/profile
                    hdiutil unmount "/Volumes/Java for OS X 2013-005"
                    rm JavaForOSX2013-05.dmg
                elif [[ $OS == 'smartos' ]]; then
                        pkgin -y in sun-jdk6-6.0.26nb1
                elif [[ $OS == 'freebsd' ]]; then
                    #TODO: headless
                        pkg_add -r openjdk6
                fi
        else
            echo "Exiting installer"
            exit 1
        fi
    fi
}

function install_git {
    if is_missing git ; then
        read -p "$(echo -e '\n\bGIT is required. Install the git package? [y/n]\n\b')" -n 1
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [[ $OS == 'debian' ]]; then
                echo "yo"
                sudo apt-get -y install git
            elif [[ $OS == 'osx' ]]; then
                cursl -S https://git-osx-installer.googlecode.com/files/git-1.7.10.3-intel-universal-snow-leopard.dmg >  git.dmg
                hdiutil mount git.dmg
                target_volume=`perl -e '\`diskutil list /\` =~ m/Apple_HFS\s(.*)/m;@a=split(/\s{2,}/, $1);print ($a[0])'`
                sudo installer -package \
                    "/Volumes/Git 1.7.10.3 Snow Leopard Intel Universal/git-1.7.10.3-intel-universal-snow-leopard.pkg" \
                    -target "/Volumes/$target_volume"
                source /etc/profile
                hdiutil unmount "/Volumes/Git 1.7.10.3 Snow Leopard Intel Universal"
            elif [[ $OS == 'smartos' ]]; then
                pkgin -y install scmgit
            elif [[ $OS == 'freebsd' ]]; then
                pkg_add -v -r git
            fi
        else
            echo "Exiting installer"
            exit 1
        fi
    fi
}

install_git
install_java

#OSMOSIS
if [[ `perl -e 'print ((qx(osmosis --v 2>&1) =~ m/INFO:\sOsmosis\sVersion\s0.(4[2-9]|[5-9][0-9])/m) ? 0:1)'` == 1 ]]; then
    read -p "$(echo -e '\n\bOsmosis 0.42+ is required. Install the latest version? [y/n]\n\b')" -n 1
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        wget -N -c http://bretth.dev.openstreetmap.org/osmosis-build/osmosis-latest.zip

        if [[ $OS == 'debian' ]]; then
            export LC_COLLATE=C
            export LC_CTYPE=en_US.UTF-8
            sudo locale-gen en_US.UTF-8
            source /etc/default/locale
            source /etc/environment
        fi

        if [[ $OS == 'smartos' ]] || [[ $OS == 'freebsd' ]]; then
            unzip -u osmosis-latest.zip -d /opt/local
            chmod +x /opt/local/bin/osmosis 
        else
            unzip -u osmosis-latest.zip -d /usr
            chmod +x /usr/bin/osmosis
        fi
    else
        echo "Exiting installer"
        exit 1
    fi
fi

#TODO: make wrapper for handling dmg/package installations on OSX

function osx_install_gdal {
    wget -N -c http://www.kyngchaos.com/files/software/frameworks/GDAL_Complete-1.9.dmg
    hdiutil mount GDAL_Complete-1.9.dmg
    target_volume=`perl -e '\`diskutil list /\` =~ m/Apple_HFS\s(.*)/m;@a=split(/\s{2,}/, $1);print ($a[0])'`
    sudo installer -package "/Volumes/GDAL Complete/GDAL Complete.pkg" -target "/Volumes/$target_volume"
    sudo ln -s /Library/Frameworks/GDAL.framework/Versions/1.9/Programs/ogr2ogr /usr/bin
    hdiutil unmount "/Volumes/GDAL Complete"
}

#OGR2OGR (GDAL)
if [[ ! `ogr2ogr --help` == "Usage"* ]]; then
    if [[ $OS == 'smartos' ]]; then
        pkgin -y in gdal-lib-1.9.1nb9
    elif [[ $OS == 'freebsd' ]]; then
        read -p "$(echo -e '\n\bGDAL is required for ogr2ogr. Install the latest version? [y/n]\n\b')" -n 1
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Updating /usr/ports..."
            #portsnap fetch update
            wget -N -c -O /var/db/ports/graphics_gdal/options https://gist.github.com/jmealo/e0129c4e5c5f419a469d/raw
            wget -N -c -O /var/db/ports/graphics_geos/options https://gist.github.com/jmealo/7c9df74068c686e45c5f/raw
            (cd /usr/ports/graphics/gdal && make -J4 install clean)
        else
            echo "Exiting installer"
            exit 1
        fi
    elif [[ $OS == 'debian' ]]; then
        read -p "$(echo -e '\n\bGDAL is required for ogr2ogr. Install the latest version? [y/n]\n\b')" -n 1
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo apt-get -y install gdal-bin
        else
            echo "Exiting installer"
            exit 1
        fi
    elif [[ $OS == 'osx' ]]; then
        read -p "$(echo -e '\n\bGDAL is required for ogr2ogr. Install the latest version? [y/n]\n\b')" -n 1
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            osx_install_gdal
        else
            echo "Exiting installer"
            exit 1
        fi

    if [[ ! `ogr2ogr --help` == "Usage"* ]]; then
        echo "GDAL Install failed; exiting"
        exit 1
    fi

    else
        echo "ogr2ogr (GDAL) is required. Please install and re-run this script."
        exit 1
    fi
fi

#Python GDAL (the OSX package includes this)
if [[ $OS == 'debian' ]]; then
    sudo apt-get -y install python-gdal
elif [[ $OS == 'osx' ]] && [[ `sw_vers` == *"10.9"* ]] && [[ ! `python -c 'import osgeo'` == '' ]]; then
    #GDAL needs to be reinstalled on 10.9 if it was installed on a lower version of OSX
    osx_install_gdal
elif [[ $OS == 'freebsd' ]]; then
    pkg_add -r py27-gdal
fi

#OSMFILTER - used to strip the .osm file down to just what we need for routing
if [[ ! -x osmfilter ]]; then
        echo "Downloading and building osmfilter..."
        wget -S -O - http://m.m.i24.cc/osmfilter.c | cc -x c - -O3 -o osmfilter
fi

#most city extracts are bounding box; we'll use the shape file to trim to the city likmits
wget -c -N http://www.pasda.psu.edu/philacity/data/phila-city_limits_shp.zip
unzip -u phila-city_limits_shp.zip

#convert to the correct coordinate system
ogr2ogr -t_srs EPSG:4326 -a_srs EPSG:4326 philly.shp city_limits.shp

#convert the city limits shape file to a .poly file so we can filter our OSM extract
wget -c -N https://trac.openstreetmap.org/export/29520/subversion/applications/utils/osm-extract/polygons/ogr2poly.py
python ogr2poly.py philly.shp

wget -c -N http://osm-extracted-metros.s3.amazonaws.com/philadelphia.osm.pbf

#trim OSM extract to philly limits
osmosis --read-bin file="philadelphia.osm.pbf" --bounding-polygon file="philly_0.poly" --write-bin file="philly.osm.pbf"

#remove nodes that aren't part of the road network
osmosis --read-bin philly.osm.pbf --way-key keyList="highway" --used-node --write-xml philadelphia.osm

#drop author information, versions, and relations [we can't do this first; because osmfilter doesn't do .osm.pbf]
./osmfilter philadelphia.osm --drop-relations --drop-author --drop-version -o=philly.osm

wget -c -N http://www.pasda.psu.edu/philacity/data/PhiladelphiaCensusBlockGroups201201.zip > PhiladelphiaCensusBlockGroups201201.zip
unzip -u PhiladelphiaCensusBlockGroups201201.zip

ogr2ogr -F GeoJSON -skip-failures -t_srs EPSG:4326 -a_srs EPSG:4326 census_block_groups.json "Philadelphia Census Block Groups/PhiladelphiaCensusBlockGroups201201.shp"

git clone git://github.com/azavea/geo-data.git
ogr2ogr -F GeoJSON -skip-failures -t_srs EPSG:4326 -a_srs EPSG:4326 philly_neighborhoods.json geo-data/Neighborhoods_Philadelphia/Neighborhoods_Philadelphia.shp

wget -c -N http://www2.census.gov/geo/tiger/TIGER2010BLKPOPHU/tabblock2010_42_pophu.zip
unzip -u tabblock2010_42_pophu.zip

ogr2ogr -F GeoJSON -skip-failures -where "COUNTYFP10='101'" tabblock2010_42_pophu.json tabblock2010_42_pophu.shp
#extract population and housing units for Philadelphia county only

#cleanup
rm philadelphia.osm.pbf
rm philadelphia.osm

wget -c -N http://gis.phila.gov/data/police_inct.zip
unzip -u police_inct.zip

