const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

app.post('/api/calculate-routes', async (req, res) => {
    const { coordinates, weights } = req.body; 
    // coordinates will come in as [[lon, lat], [lon, lat], ...]

    if (!coordinates || coordinates.length < 2) {
        return res.status(400).json({ error: "Need at least 2 points" });
    }

    // Format coordinates for Mapbox: lon,lat;lon,lat
    const coordsString = coordinates.map(c => `${c[0]},${c[1]}`).join(';');
    const mapboxToken = process.env.MAPBOX_TOKEN;
    
    // Call Mapbox Directions API for the real route geometry and distance
    const mapboxUrl = `https://api.mapbox.com/directions/v5/mapbox/driving/${coordsString}?geometries=geojson&access_token=${mapboxToken}`;

    try {
        const mapboxRes = await fetch(mapboxUrl);
        const mapboxData = await mapboxRes.json();

        if (mapboxData.code !== 'Ok') {
            return res.status(400).json({ error: "Could not find a route." });
        }

        // Mapbox returns distance in meters. Convert to km.
        const route = mapboxData.routes[0];
        const distanceKm = route.distance / 1000; 
        const geometry = route.geometry; // The line to draw on the map

        const modes = [
            { name: 'Walk', wait: 0, speed: 5, base: 0, rate: 0, emissions: 0 },
            { name: 'Rapido', wait: 5, speed: 25, base: 20, rate: 6, emissions: 45 },
            { name: 'Auto', wait: 3, speed: 18, base: 40, rate: 15, emissions: 90 },
            { name: 'Bus', wait: 15, speed: 15, base: 10, rate: 2, emissions: 30 }
        ];

        let results = modes.map(mode => {
            const time = mode.wait + ((distanceKm / mode.speed) * 60);
            const cost = mode.base + (distanceKm * mode.rate);
            const pollution = distanceKm * mode.emissions;
            return { name: mode.name, time, cost, pollution };
        });

        const maxT = Math.max(...results.map(r => r.time));
        const maxC = Math.max(...results.map(r => r.cost)) || 1; 
        const maxP = Math.max(...results.map(r => r.pollution)) || 1;

        results = results.map(r => {
            const score = 
                (weights.time * (r.time / maxT)) + 
                (weights.cost * (r.cost / maxC)) + 
                (weights.pollution * (r.pollution / maxP));
            return { ...r, score: score.toFixed(2) };
        });

        results.sort((a, b) => a.score - b.score);

        // Send back the best option AND the geometry to draw the line
        res.json({ 
            recommended: results[0], 
            all_options: results,
            distanceKm: distanceKm.toFixed(2),
            routeGeometry: geometry 
        });

    } catch (error) {
        console.error(error);
        res.status(500).json({ error: "Server error calculating route" });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Routing Engine running on port ${PORT}`));