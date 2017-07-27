var m = require("mithril");

var Racks = {
    list: [],
    loadRacks: function() {
        return m.request({
            method: "GET",
            url: "http://10.64.223.75:5000/rack",
            withCredentials: true
        }).then(function(result) {
            console.log("Result is...");
            console.log(result);
            Racks.list = result.data.racks;
        });
    }
};

module.exports = Racks;
