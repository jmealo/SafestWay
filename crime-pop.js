var
    csv = require('csv'),
    fs = require('fs'),
    async = require('async'),
    multimeter = require('multimeter'),
    multi = multimeter(process),
    sys = require('sys'),
    exec = require('child_process').exec,
    inside = require('point-in-polygon'),
    cluster = require('cluster'),
    numCPUs = require('os').cpus().length,
    cursor = 0;

//TODO: Find a way to write Status... DONE more neatly (status updates)

multi.on('^C', function() {
    process.exit(1);
});

multi.charm.reset();

function lineCount(filename, callback) {
    exec('wc -l ' + filename + ' | cut -d " " -f 3', function (error, stdout, stderr) {
        callback(error, stdout.trim());
    });
}

function writeStatus(msg, pos) {
    if(!pos) {
        cursor++;
        pos = cursor;
    }
    multi.charm.position(0, pos);
    multi.charm.write(msg);
    multi.charm.cursor(false);

    return pos;
}

function loadPoints(filename, callback) {
    var msg = "Loading GeoJSON points from " + filename + "... ";
    var pos = writeStatus(msg);
    fs.readFile(filename, function(err, data) {
       var features = JSON.parse(data).features, points = [];
       features.forEach(function (feature) {
           points.push(feature.geometry.coordinates);
       });
        cursor = writeStatus(msg + "Done\n", pos);
        callback(null, points);
    });
}

cluster.setupMaster({
    exec : "crime-block-worker.js",
    silent : true
});

if (cluster.isMaster) {
    var bar;

    async.series([
        function loadCensusBlocks(callback) {
            loadPoints('data/source/census_blocks.json', function (err, points) {
                callback(err, points);
            });
        },
        function loadCrimes(callback) {
            loadPoints('./crimes.json', function (err, points) {
                callback(err, points);
            });
        }
    ],
        function(err, results) {
            var child, crimes = results[1], geoms = results[0], crime_count = crimes.length, crimes_done = 0, crimes_per_thread = Math.round(crime_count / numCPUs), pos, msg;
            msg = "Spawning " + numCPUs + " workers for processing... ";
            pos = writeStatus(msg);
            for (var i = 0; i < numCPUs; i++) {
                child = cluster.fork({});
                child.send({crimes: crimes.slice(i * crimes_per_thread, (i+1) * crimes_per_thread), geoms: geoms});

                child.on('message', function(msg) {
                    crimes_done += msg.crimes.length;
                    bar.ratio(crimes_done, crime_count);
                    msg.crimes.forEach(function(crime) {
                       console.log(crimes[crime]);
                    });
                });
            }
            writeStatus(msg + " Done\n", pos);
            writeStatus("This process will take a few minutes. It starts off slow and then speeds up. Please wait.\n");

            bar = multi(0, cursor + 1, {width: 80});
            bar.ratio(0, crime_count);

            cluster.disconnect(function() {
                bar.ratio(crime_count, crime_count);
                writeStatus("\n\nProcess complete.\n");
                process.exit(0);
            });
        });

    process.on('exit', function(code, signal) {
        cluster.disconnect();
        multi.charm.cursor(true);
    });

}