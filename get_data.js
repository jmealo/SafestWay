/*jslint devel: true, node: true, plusplus: true, unparam: true, sloppy: true, todo: true */

//TODO: Make data sources "plugin style" with urlBuilder and an array of steps for ETL
//TODO: Uniform method to cite data source and provide terms/license for data
//TODO: Interactive command prompt interface
//TODO: HTML front end that generates command line options using a friendly GUI
//TODO: Extraction status bars based on estimated compression ratio

var argv = require('optimist')
        .usage('Download, extract and transform OpenStreetMap and Census data for the given state. \nUsage: $0\n\n' +
            'To load data for Philadelphia: \n$0 -s PA -c philadelphia')
        .alias('s', 'state')
        .describe('state', 'State abbreviation (PA)')
        .demand('state')
        .alias('c', 'city')
        .describe('city', 'City (Philadelphia)')
        .describe('agree', 'Do you agree to the PASDA Terms of Use and Disclaimer?')
        .alias('a', 'agree')
        .argv,
    fs = require('fs'),
    sys = require('sys'),
    exec = require('child_process').exec,
    async = require('async'),
    emitter = require('events').EventEmitter,
    http = require('http-get'),
    multimeter = require('multimeter'),
    multi = multimeter(process),
    urlBuilder = require('./lib/url_builder.js'),
    city = (argv.hasOwnProperty('city')) ? argv.city.toString().toLowerCase() : undefined,
    state = argv.state.toString().toUpperCase(),
    data = [],
    data_dir = "data/source/",
    downloads = [],
    etl = [],
    bars = [],
    cursor = 4;

multi.charm.setMaxListeners(0);
//prevent progress bar event emitters from hitting node's max

multi.on('^C', process.exit);
multi.charm.reset();

function bytesToPretty(size) {
    var SizePrefixes = ['', 'K', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y'],
        t2 = Math.min(Math.round(Math.log(size) / Math.log(1024)), SizePrefixes.length - 1);

    return (size <= 0) ? 0 : (Math.round(size * 100 / Math.pow(1024, t2)) / 100) + ' ' + SizePrefixes[t2] + 'iB';
} //Based on: Janus Troelsen | stackoverflow | http://goo.gl/aHv2N

function writeStatus(msg, pos) {
    if (pos === undefined) {
        if (cursor === 4) {
            cursor = (bars.length > 0) ? bars.length + 4 : 4;
        }
        cursor++;
        pos = cursor;
    }

    multi.charm.position(0, pos);
    multi.charm.write(msg);
    multi.charm.cursor(false);

    return pos;
}

function unzipFile(filename, callback) {
    var msg = "Unzipping " + filename + "... ",
        pos = writeStatus(msg);

    exec('unzip -uo ' + filename + ' -d ' + data_dir, function(err, results) {
        writeStatus(msg + " Done", pos);
        callback(err, results);
    });
}

function bunzipFile(filename, callback) {
    exec('cd ' + data_dir + ' && bunzip2 -f ' + filename, callback);
}

function strPad(str, length, pad) {
    var arr = [];
    pad = pad || '0';
    str = str.toString();
    arr.length = (length - str.length + 1);
    return str.length >= length ? str : arr.join(pad) + str;
}

function extractFile(data_source, callback) {
    if (data_source.local.toLowerCase().indexOf('.zip') !== -1) {
        unzipFile(data_source.local, function (err) {
            callback(err, data_source);
        });
    } else if (data_source.local.toLowerCase().indexOf('.bz2') !== -1) {
        bunzipFile(data_source.filename, function (err) {
            callback(err, data_source);
        });
    } else {
        callback(null, data_source);
    }
}

function emptyFunc() {

}

function downloadFile(data_source, callback) {
    var total_bytes = 0, recv_bytes = 0, total_pretty = 0, out_stream, bar,
        file_name = data_source.url.substring(data_source.url.lastIndexOf('/') + 1),
        out_filename = data_dir + file_name;
    data_source.filename = file_name;
    data_source.local = out_filename;

    bar = multi(0, bars.length + 4, {
        width: 34,
        solid: {
            text: '|',
            foreground: 'white',
            background: 'blue'
        },
        empty: { text: ' ' }
    });

    bars.push(bar);

    http.get({ url: data_source.url, stream: true },
        function (error, result) {
            if (error) {
                callback(error, null);
            } else {
                fs.stat(out_filename, function (err, stats) {
                    total_bytes = result.headers['content-length'];

                    if (!stats || (stats && stats.size !== parseInt(total_bytes, 10))) {
                        total_pretty = bytesToPretty(total_bytes);
                        total_pretty = total_pretty.replace(' ', strPad('', (10 - total_pretty.length), ' '));
                        total_pretty = ' [' + total_pretty + '] ' + file_name;
                        out_stream = fs.createWriteStream(out_filename);

                        result.stream.pipe(out_stream);
                        result.stream.resume();
                    } else {
                        extractFile(data_source, callback);
                        bar.percent(100, "[SKIPPED] " + file_name);
                    }
                });

                result.stream.on('data', function (data) {
                    recv_bytes += data.length;
                    bar.ratio(recv_bytes, total_bytes, total_pretty);
                });

                result.stream.on('error', function (error) {
                    if (error) {
                        throw error;
                    }
                    //TODO: error handling
                });

                result.stream.on('end', function () {
                    out_stream.end();
                    extractFile(data_source, callback);
                });
            }
        });
}

data.push({
    url: urlBuilder.census_block_group_population(state),
    etl: emptyFunc,
    str: 'Population and Housing Unit Data for Census Block groups'
});

data.push({
    url: urlBuilder.census_block_groups(state),
    etl: emptyFunc,
    str: 'Census Block Group Shape Files'
});

data.push({
    url: urlBuilder.osm_state_extract(state),
    etl: emptyFunc,
    str: 'OpenStreetMaps State Extract'
});

var cities = {
    philadelphia: function philadelphia() {
        //Don't download the state extract; download the city instead
        var x;

        for (x = 0; x < data.length; x++) {
            if (data[x].str === 'OpenStreetMaps State Extract') {
                data[x] = {
                    url: 'http://osm-extracted-metros.s3.amazonaws.com/philadelphia.osm.pbf',
                    etl: emptyFunc,
                    str: 'OpenStreetMaps City Extract'
                };
            }
        }

        if (!argv.agree) {
            console.warn('You must agree to the PASDA Terms of Use and Disclaimer before you can continue:');
            console.warn('http://www.pasda.psu.edu/uci/PhiladelphiaAgreement.asp');
            console.warn('If you agree to the terms at the URL above: re-run this program with the --agree flag');
            process.exit(1);
        }

        data.push({
            url: 'http://www.pasda.psu.edu/philacity/data/phila-city_limits_shp.zip',
            etl: emptyFunc,
            str: 'City Limits Shape File'
        });

        data.push({
            url: 'http://gis.phila.gov/data/police_inct.zip',
            etl: emptyFunc,
            str: 'Crime Incidents (CSV)'
        });

        data.push({
            url: 'http://www.pasda.psu.edu/philacity/data/PhiladelphiaSchool_Facilities201302.zip',
            etl: emptyFunc,
            str: 'Schools Shape File'
        });
    }
};

multi.charm.write("====================================\n");
multi.charm.write("SafestWay Download & Extraction Tool\n");
multi.charm.write("------------------------------------\n\n");

if (!urlBuilder.isStateAbbr(state)) {
    console.error("Please specify state as a two letter abbreviation. (Pennsylvania = PA)");
    process.exit(1);
}

if (city) {
    if (cities.hasOwnProperty(city)) {
        cities[city]();
    } else {
        console.error("Sorry no city specific routine has been specified for: " + city);
        console.log("Try running again without specifying a city.");
        process.exit(1);
    }
}

data.forEach(function (data_source) {
    downloads.push(function (callback) {
        downloadFile(data_source, callback);
    });
    etl.push(function (callback) {
        data_source.etl(data_source, callback);
    });
});

async.parallel(downloads, function (err, results) {
    if (err) {
        throw err;
    }
    console.log("\n\nData is ready and extracted! =)");
    process.exit(0);
});