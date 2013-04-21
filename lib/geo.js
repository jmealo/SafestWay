var neighborhoods = require('./data/neighborhoods.json'),
    census_blocks = require('./data/census_blocks.json'),
    inside = require('point-in-polygon');

function findPoint(lon, lat, callback) {
    var return_val = {error: 'no result'}, point = [lon, lat], neighborhood, census_block;

    //find neighborhood
    for(var name in neighborhoods) {
        if (inside(point, neighborhoods[name])) {
            neighborhood = name;
        }
    }

    if(neighborhood) {
        //search census blocks within neighborhood for match

        for(var x = 0, len = census_blocks[neighborhood].length; x < len; x++) {
            census_block = census_blocks[neighborhood][x];
            if (inside(point, census_block.geom)) {
                return_val = {
                    neighborhood : neighborhood,
                    pop          : census_block.pop,
                    housing      : census_block.housing,
                    STATEFP10    : census_block.id.substr(0, 2),
                    COUNTYFP10   : census_block.id.substr(2, 3),
                    TRACTCE10    : census_block.id.substr(5, 6),
                    BLOCKCE      : census_block.id.substr(11, 4),
                    BLOCKID10    : census_block.id
                };
            }
        }
    }

    callback(return_val);
}

module.exports.phillyPoint = findPoint;