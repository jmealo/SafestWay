/*jslint devel: true, node: true, plusplus: true, unparam: true, sloppy: true, todo: true */
//TODO: Store state_abbr in a JSON file once directory structure is finalized

var state_abbr = {
    "AL": {
        "ansi": "01",
        "name": "Alabama"
    },
    "AK": {
        "ansi": "02",
        "name": "Alaska"
    },
    "AZ": {
        "ansi": "04",
        "name": "Arizona"
    },
    "AR": {
        "ansi": "05",
        "name": "Arkansas"
    },
    "CA": {
        "ansi": "06",
        "name": "California"
    },
    "CO": {
        "ansi": "08",
        "name": "Colorado"
    },
    "CT": {
        "ansi": "09",
        "name": "Connecticut"
    },
    "DE": {
        "ansi": "10",
        "name": "Delaware"
    },
    "DC": {
        "ansi": "11",
        "name": "District of Columbia"
    },
    "FL": {
        "ansi": "12",
        "name": "Florida"
    },
    "GA": {
        "ansi": "13",
        "name": "Georgia"
    },
    "HI": {
        "ansi": "15",
        "name": "Hawaii"
    },
    "ID": {
        "ansi": "16",
        "name": "Idaho"
    },
    "IL": {
        "ansi": "17",
        "name": "Illinois"
    },
    "IN": {
        "ansi": "18",
        "name": "Indiana"
    },
    "IA": {
        "ansi": "19",
        "name": "Iowa"
    },
    "KS": {
        "ansi": "20",
        "name": "Kansas"
    },
    "KY": {
        "ansi": "21",
        "name": "Kentucky"
    },
    "LA": {
        "ansi": "22",
        "name": "Louisiana"
    },
    "ME": {
        "ansi": "23",
        "name": "Maine"
    },
    "MD": {
        "ansi": "24",
        "name": "Maryland"
    },
    "MA": {
        "ansi": "25",
        "name": "Massachusetts"
    },
    "MI": {
        "ansi": "26",
        "name": "Michigan"
    },
    "MN": {
        "ansi": "27",
        "name": "Minnesota"
    },
    "MS": {
        "ansi": "28",
        "name": "Mississippi"
    },
    "MO": {
        "ansi": "29",
        "name": "Missouri"
    },
    "MT": {
        "ansi": "30",
        "name": "Montana"
    },
    "NE": {
        "ansi": "31",
        "name": "Nebraska"
    },
    "NV": {
        "ansi": "32",
        "name": "Nevada"
    },
    "NH": {
        "ansi": "33",
        "name": "New Hampshire"
    },
    "NJ": {
        "ansi": "34",
        "name": "New Jersey"
    },
    "NM": {
        "ansi": "35",
        "name": "New Mexico"
    },
    "NY": {
        "ansi": "36",
        "name": "New York"
    },
    "NC": {
        "ansi": "37",
        "name": "North Carolina"
    },
    "ND": {
        "ansi": "38",
        "name": "North Dakota"
    },
    "OH": {
        "ansi": "39",
        "name": "Ohio"
    },
    "OK": {
        "ansi": "40",
        "name": "Oklahoma"
    },
    "OR": {
        "ansi": "41",
        "name": "Oregon"
    },
    "PA": {
        "ansi": "42",
        "name": "Pennsylvania"
    },
    "RI": {
        "ansi": "44",
        "name": "Rhode Island"
    },
    "SC": {
        "ansi": "45",
        "name": "South Carolina"
    },
    "SD": {
        "ansi": "46",
        "name": "South Dakota"
    },
    "TN": {
        "ansi": "47",
        "name": "Tennessee"
    },
    "TX": {
        "ansi": "48",
        "name": "Texas"
    },
    "UT": {
        "ansi": "49",
        "name": "Utah"
    },
    "VT": {
        "ansi": "50",
        "name": "Vermont"
    },
    "VA": {
        "ansi": "51",
        "name": "Virginia"
    },
    "WA": {
        "ansi": "53",
        "name": "Washington"
    },
    "WV": {
        "ansi": "54",
        "name": "West Virginia"
    },
    "WI": {
        "ansi": "55",
        "name": "Wisconsin"
    },
    "WY": {
        "ansi": "56",
        "name": "Wyoming"
    },
    "AS": {
        "ansi": "60",
        "name": "American Samoa"
    },
    "GU": {
        "ansi": "66",
        "name": "Guam"
    },
    "MP": {
        "ansi": "69",
        "name": "Northern Mariana Islands"
    },
    "PR": {
        "ansi": "72",
        "name": "Puerto Rico"
    },
    "UM": {
        "ansi": "74",
        "name": "U.S. Minor Outlying Islands"
    },
    "VI": {
        "ansi": "78",
        "name": "U.S. Virgin Islands"
    }
};

function isStateAbbr(state) {
    return (state_abbr.hasOwnProperty(state.toString().toUpperCase()));
}

function osm_state_extract(state) {
    var base_url = "http://download.geofabrik.de/north-america/us/%s-latest.osm.pbf",
        url = "";

    if (isStateAbbr(state) && (parseInt(state_abbr[state].ansi, 10) <= 56)) {
        //ANSI codes above 56 are territories that cloudmade doesn't provide
        url = base_url.replace(/%s/g, state_abbr[state].name.toLowerCase().replace(/\s/g, '-'));
    }

    return url;
}

/*
 //Cloud Made has .osm.bz2 (XML format)
 function osm_state_extract(state) {
 'use strict';
 var base_url = "http://downloads.cloudmade.com/americas/northern_america/united_states/%s/%s.osm.bz2",
 url = "";

 if (isStateAbbr(state) && (parseInt(state_abbr[state].ansi, 10) <= 56)) {
 //ANSI codes above 56 are territories that cloudmade doesn't provide
 url = base_url.replace(/%s/g, state_abbr[state].name.toLowerCase());
 }

 return url;
 }*/

function census_block_groups(state) {
    var base_url = 'http://www2.census.gov/geo/tiger/TIGER2012/BG/tl_2012_%s_bg.zip',
        url = "";

    state = state.toString().toUpperCase();

    if (isStateAbbr(state)) {
        url = base_url.replace(/%s/g, state_abbr[state].ansi);
    }

    return url;
}

function census_block_group_population(state) {
    var base_url = 'http://www2.census.gov/geo/tiger/TIGER2010BLKPOPHU/tabblock2010_%s_pophu.zip',
        url = "";

    state = state.toString().toUpperCase();

    if (isStateAbbr(state)) {
        url = base_url.replace(/%s/g, state_abbr[state].ansi);
    }

    return url;
}

module.exports = {
    census_block_group_population: census_block_group_population,
    census_block_groups : census_block_groups,
    osm_state_extract : osm_state_extract,
    isStateAbbr: isStateAbbr
};