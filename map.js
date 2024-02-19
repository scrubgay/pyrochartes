const L = require("leaflet");
const map = L.map('map', {preferCanvas: true})
.setView([27.49233, -81.43461], 10);
L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>'
}).addTo(map);

async function fetchJSON(url) {
    return fetch(url)
      .then(function(response) {
        return response.json();
      });
  }

const data = fetchJSON("data.geojson").then(data => data);

data.then(data => {
    for (let feature of data.features) {
        const color = feature.properties.Growing ? "#ffa500" : "#6495ed";
        const opacity = feature.properties.ThisSeason ? 1 : 0.25;
        const coords = [feature.geometry.coordinates[1], feature.geometry.coordinates[0]];
        L.circleMarker(coords, {radius: 2.5, color: color, opacity: opacity, weight: 0.25}).addTo(map);
    }
})