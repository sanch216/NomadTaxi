import { useEffect, useState } from 'react';
import { MapContainer, TileLayer, CircleMarker, Popup } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import { heatmapService } from '../services/api';
import { HeatmapCell } from '../types';

function LiveMap() {
  const [cells, setCells] = useState<HeatmapCell[]>([]);
  const [loading, setLoading] = useState(true);
  const [lastUpdated, setLastUpdated] = useState<Date>(new Date());

  const fetchHeatmap = async () => {
    try {
      const response = await heatmapService.getLiveHeatmap();
      setCells(response.data);
      setLastUpdated(new Date());
    } catch (error) {
      console.error('Failed to load heatmap:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchHeatmap();
    const interval = setInterval(fetchHeatmap, 5000); // refresh every 5 seconds
    return () => clearInterval(interval);
  }, []);

  // Determine color based on weight
  const getColor = (weight: number) => {
    if (weight > 0.8) return '#ff0000'; // High demand
    if (weight > 0.5) return '#ffaa00'; // Medium demand
    if (weight > 0.2) return '#ffff00'; // Low demand
    return '#00ff00'; // Normal
  };

  return (
    <div className="users-page" style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div className="page-header" style={{ marginBottom: '1rem' }}>
        <h1>Live Map & Heatmap</h1>
        <div style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>
          Last updated: {lastUpdated.toLocaleTimeString()}
        </div>
      </div>

      <div style={{ flex: 1, position: 'relative', borderRadius: '12px', overflow: 'hidden', minHeight: '600px', border: '1px solid var(--border-color)' }}>
        {loading && cells.length === 0 ? (
          <div style={{ position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)', zIndex: 1000, background: 'var(--bg-card)', padding: '1rem', borderRadius: '8px' }}>
            Loading map data...
          </div>
        ) : null}
        
        <MapContainer center={[42.8746, 74.5698]} zoom={12} style={{ height: '100%', width: '100%' }}>
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          
          {cells.map((cell) => (
            <CircleMarker
              key={cell.cellId}
              center={[cell.lat, cell.lon]}
              radius={Math.max(10, cell.weight * 30)}
              pathOptions={{
                color: getColor(cell.weight),
                fillColor: getColor(cell.weight),
                fillOpacity: 0.6,
                weight: 0
              }}
            >
              <Popup>
                <div>
                  <strong>Cell ID:</strong> {cell.cellId}<br/>
                  <strong>Demand Weight:</strong> {cell.weight.toFixed(2)}
                </div>
              </Popup>
            </CircleMarker>
          ))}
        </MapContainer>
      </div>
    </div>
  );
}

export default LiveMap;
