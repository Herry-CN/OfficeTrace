import { MapContainer, TileLayer, Polyline, CircleMarker, Marker, Popup, useMap } from 'react-leaflet'
import L from 'leaflet'
import { useEffect } from 'react'
import {
  getDeviceTypeLabel,
  type AlertItem,
  type DeviceItem,
  type Mission,
} from '../data/mockData'
import type { Locale } from '../i18n/types'
import { uiMessages, statusLabel } from '../i18n/ui'

function fitIcon(label: string, color: string) {
  return L.divIcon({
    className: 'custom-marker',
    html: `<div style="
      width:22px;height:22px;border-radius:50%;
      background:${color};color:#041018;font-weight:700;font-size:11px;
      display:flex;align-items:center;justify-content:center;
      border:2px solid #dff7ff;box-shadow:0 0 10px ${color};
    ">${label}</div>`,
    iconSize: [22, 22],
    iconAnchor: [11, 11],
  })
}

function FitBounds({ mission, alerts }: { mission: Mission; alerts: AlertItem[] }) {
  const map = useMap()
  useEffect(() => {
    const points = [...mission.path, ...alerts.map((a) => a.coords)]
    if (points.length === 0) return
    const bounds = L.latLngBounds(points.map(([lat, lng]) => [lat, lng] as [number, number]))
    map.fitBounds(bounds.pad(0.25))
  }, [map, mission, alerts])
  return null
}

const deviceColor: Record<DeviceItem['type'], string> = {
  drone: '#3ecbff',
  robotDog: '#f0c14b',
  camera: '#2ee59d',
  dock: '#9a7bff',
  starlink: '#ff8ad8',
}

interface Props {
  mission: Mission
  devices: DeviceItem[]
  alerts: AlertItem[]
  selectedAlertId?: string
  onSelectAlert?: (id: string) => void
  locale: Locale
}

export function MapCanvas({
  mission,
  devices,
  alerts,
  selectedAlertId,
  onSelectAlert,
  locale,
}: Props) {
  const center = mission.path[0] ?? ([-0.45, 39.65] as [number, number])
  const ui = uiMessages[locale]

  return (
    <div className="map-root" data-testid="map-canvas">
      <MapContainer center={center} zoom={15} zoomControl={false} attributionControl={false}>
        <TileLayer
          url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
        />
        <FitBounds mission={mission} alerts={alerts} />
        <Polyline positions={mission.path} pathOptions={{ color: '#ff6a3d', weight: 3, opacity: 0.95 }} />
        {mission.waypoints.map((wp) => (
          <Marker key={wp.id} position={wp.coords} icon={fitIcon(String(wp.id), '#3ecbff')}>
            <Popup>
              {ui.waypoint} {wp.id}
              <br />
              {wp.action}
              <br />
              {ui.gimbalPitch} {wp.gimbalPitch}°
            </Popup>
          </Marker>
        ))}
        {devices.map((d) => (
          <CircleMarker
            key={d.id}
            center={d.coords}
            radius={d.type === 'drone' || d.type === 'robotDog' ? 8 : 6}
            pathOptions={{
              color: '#dff7ff',
              fillColor: deviceColor[d.type],
              fillOpacity: 0.95,
              weight: 2,
            }}
          >
            <Popup>
              {d.name}
              <br />
              {getDeviceTypeLabel(locale, d.type)} · {statusLabel(ui, d.status)}
              <br />
              {d.location}
            </Popup>
          </CircleMarker>
        ))}
        {alerts.map((a) => (
          <CircleMarker
            key={a.id}
            center={a.coords}
            radius={selectedAlertId === a.id ? 11 : 8}
            eventHandlers={{ click: () => onSelectAlert?.(a.id) }}
            pathOptions={{
              color: '#fff',
              fillColor: '#ff4d5e',
              fillOpacity: selectedAlertId === a.id ? 1 : 0.8,
              weight: 2,
            }}
          >
            <Popup>
              {a.name}
              <br />
              {a.location}
            </Popup>
          </CircleMarker>
        ))}
      </MapContainer>
      <div className="map-legend">
        <div className="legend-item">
          <span className="dot path" />
          {ui.mapRoute}
        </div>
        <div className="legend-item">
          <span className="dot drone" />
          {ui.mapDrone}
        </div>
        <div className="legend-item">
          <span className="dot dog" />
          {ui.mapDog}
        </div>
        <div className="legend-item">
          <span className="dot camera" />
          {ui.mapSensor}
        </div>
        <div className="legend-item">
          <span className="dot alert" />
          {ui.mapAlert}
        </div>
      </div>
    </div>
  )
}
