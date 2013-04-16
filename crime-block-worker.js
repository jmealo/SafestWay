var inside = require('point-in-polygon');

process.on('message', function(msg) {
    crimes = msg.crimes, geoms = msg.geoms, matches = [];

    geoms.forEach(function (geom, geom_index) {
        matches = [];

        crimes.forEach(function(crime, crime_index) {
            if(inside(crime, geom[0])) {
                matches.push(crime_index);
            }
        });

        if(matches.length > 0) {
            process.send({block_index: geom_index, crimes: matches});
        }
    });

    process.exit(0);
});