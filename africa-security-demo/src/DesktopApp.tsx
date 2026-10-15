import { useEffect, useMemo, useState } from 'react'
import { MapCanvas } from './components/MapCanvas'
import {
  getAlerts,
  getArchitectureLayers,
  getCampMission,
  getDevices,
  getLinkageSteps,
  getVillaMission,
  kpiStats,
  type AlertItem,
  type AlertStatus,
  type Mission,
} from './data/mockData'
import { useLocale } from './i18n/LocaleContext'
import { formatTemplate, statusLabel } from './i18n/ui'
import type { Locale } from './i18n/types'

type TopTab = 'map' | 'alerts' | 'devices' | 'linkage' | 'flight' | 'architecture'
type BottomModule = 'ops' | 'alerts' | 'airground' | 'assets' | 'solution'
type SceneMode = 'camp' | 'villa'

function formatNow() {
  const d = new Date()
  const pad = (n: number) => String(n).padStart(2, '0')
  return {
    time: `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`,
    date: `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`,
  }
}

export default function DesktopApp() {
  const { locale, setLocale, ui } = useLocale()
  const [clock, setClock] = useState(formatNow)
  const [scene, setScene] = useState<SceneMode>('camp')
  const [topTab, setTopTab] = useState<TopTab>('flight')
  const [module, setModule] = useState<BottomModule>('ops')
  const [alertFilter, setAlertFilter] = useState<'all' | AlertStatus>('all')
  const [selectedAlertId, setSelectedAlertId] = useState('ALT-20261013-88421')
  const [alertStatus, setAlertStatus] = useState<Record<string, AlertStatus>>({})

  const allAlerts = useMemo(() => getAlerts(locale), [locale])
  const devices = useMemo(() => getDevices(locale), [locale])
  const campMission = useMemo(() => getCampMission(locale), [locale])
  const villaMission = useMemo(() => getVillaMission(locale), [locale])
  const linkageSteps = useMemo(() => getLinkageSteps(locale), [locale])
  const architectureLayers = useMemo(() => getArchitectureLayers(locale), [locale])

  useEffect(() => {
    const t = setInterval(() => setClock(formatNow()), 1000)
    return () => clearInterval(t)
  }, [])

  useEffect(() => {
    if (module === 'alerts') setTopTab('alerts')
    if (module === 'airground') setTopTab('linkage')
    if (module === 'assets') setTopTab('devices')
    if (module === 'solution') setTopTab('architecture')
    if (module === 'ops' && !['map', 'flight', 'alerts'].includes(topTab)) setTopTab('flight')
  }, [module])

  useEffect(() => {
    setAlertStatus((prev) => {
      const next = { ...prev }
      for (const alert of allAlerts) {
        if (!(alert.id in next)) next[alert.id] = alert.status
      }
      return next
    })
  }, [allAlerts])

  const topTabs: { id: TopTab; label: string }[] = [
    { id: 'map', label: ui.tabMap },
    { id: 'alerts', label: ui.tabAlerts },
    { id: 'devices', label: ui.tabDevices },
    { id: 'linkage', label: ui.tabLinkage },
    { id: 'flight', label: ui.tabFlight },
    { id: 'architecture', label: ui.tabArchitecture },
  ]

  const bottomModules: { id: BottomModule; label: string; icon: string }[] = [
    { id: 'ops', label: ui.navOps, icon: '◎' },
    { id: 'alerts', label: ui.navAlerts, icon: '⚠' },
    { id: 'airground', label: ui.navAirGround, icon: '✈' },
    { id: 'assets', label: ui.navAssets, icon: '▣' },
    { id: 'solution', label: ui.navSolution, icon: '◆' },
  ]

  const mission: Mission = scene === 'camp' ? campMission : villaMission
  const sceneAlerts = useMemo(
    () => allAlerts.filter((a) => (scene === 'camp' ? a.scene === 'camp' : a.scene !== 'camp')),
    [allAlerts, scene],
  )
  const selectedAlert: AlertItem =
    allAlerts.find((a) => a.id === selectedAlertId) ?? allAlerts[0]

  const filteredAlerts = useMemo(() => {
    const list = sceneAlerts.map((a) => ({ ...a, status: alertStatus[a.id] ?? a.status }))
    if (alertFilter === 'all') return list
    return list.filter((a) => a.status === alertFilter)
  }, [sceneAlerts, alertFilter, alertStatus])

  const sceneDevices = useMemo(() => {
    return devices.filter((d) => d.site === 'both' || d.site === scene)
  }, [devices, scene])

  const activeWaypoint = mission.waypoints[3] ?? mission.waypoints[0]

  return (
    <div className="app-shell" data-testid="africa-security-demo" data-locale={locale}>
      <header className="header">
        <div className="header-left">
          <div className="header-clock">{clock.time}</div>
          <div className="header-date">
            {clock.date} · {ui.kenyaOps}
          </div>
        </div>
        <div className="header-title">
          <h1>{ui.title}</h1>
          <p>{ui.subtitle}</p>
        </div>
        <div className="header-right">
          <div className="lang-switch" role="group" aria-label={ui.langSwitch}>
            {([
              ['zh', '中文'],
              ['en', 'EN'],
            ] as const).map(([code, label]) => (
              <button
                key={code}
                type="button"
                className={`lang-btn ${locale === code ? 'active' : ''}`}
                aria-pressed={locale === code}
                onClick={() => setLocale(code as Locale)}
              >
                {label}
              </button>
            ))}
          </div>
          <div className="tabs" role="group" aria-label={ui.sceneSwitch}>
            <button
              className={`tab ${scene === 'camp' ? 'active' : ''}`}
              onClick={() => {
                setScene('camp')
                setSelectedAlertId('ALT-20261013-88421')
              }}
            >
              {ui.sceneCamp}
            </button>
            <button
              className={`tab ${scene === 'villa' ? 'active' : ''}`}
              onClick={() => {
                setScene('villa')
                setSelectedAlertId('ALT-20261013-88390')
              }}
            >
              {ui.sceneVilla}
            </button>
          </div>
          <div className="user-chip">
            <div className="user-avatar">A</div>
            <span>{ui.userRole}</span>
          </div>
        </div>
      </header>

      <main className="main-stage">
        <aside className="panel" data-testid="left-panel">
          <div className="panel-title">
            <span>{ui.alertDetails}</span>
            <span className="tag">{ui.aiFusion}</span>
          </div>
          <div className="panel-body">
            <div className="ring-wrap">
              <div className="ring">
                <div>
                  <strong>{kpiStats.dronesOnline}</strong>
                  <span>{ui.dronesOnline}</span>
                </div>
              </div>
            </div>
            <div className="metric-grid">
              <div className="metric">
                <div className="n">{kpiStats.dogsOnline}</div>
                <div className="l">{ui.robotDogs}</div>
              </div>
              <div className="metric">
                <div className="n">{kpiStats.camerasOnline}</div>
                <div className="l">{ui.sensors}</div>
              </div>
              <div className="metric">
                <div className="n">{kpiStats.pendingAlerts}</div>
                <div className="l">{ui.pending}</div>
              </div>
            </div>

            <h3 className="section-title">{selectedAlert.name}</h3>
            <div className="thumb-row">
              {selectedAlert.thumbnails.map((t) => (
                <div key={t} className="thumb">
                  {t === 'thermal' ? ui.thermal : ui.optical}
                </div>
              ))}
            </div>
            <div className="kv-list">
              <div className="kv-row">
                <span className="k">{ui.alertId}</span>
                <span className="v">{selectedAlert.id}</span>
              </div>
              <div className="kv-row">
                <span className="k">{ui.alertType}</span>
                <span className="v">{selectedAlert.type}</span>
              </div>
              <div className="kv-row">
                <span className="k">{ui.location}</span>
                <span className="v">{selectedAlert.location}</span>
              </div>
              <div className="kv-row">
                <span className="k">{ui.coords}</span>
                <span className="v">
                  {selectedAlert.coords[0].toFixed(6)}, {selectedAlert.coords[1].toFixed(6)}
                </span>
              </div>
              <div className="kv-row">
                <span className="k">{ui.alertTime}</span>
                <span className="v">{selectedAlert.time}</span>
              </div>
              <div className="kv-row">
                <span className="k">{ui.alertSource}</span>
                <span className="v">{selectedAlert.source}</span>
              </div>
              <div className="kv-row">
                <span className="k">{ui.handleStatus}</span>
                <span className="v">
                  <select
                    className="select"
                    value={alertStatus[selectedAlert.id] ?? selectedAlert.status}
                    onChange={(e) =>
                      setAlertStatus((prev) => ({
                        ...prev,
                        [selectedAlert.id]: e.target.value as AlertStatus,
                      }))
                    }
                    aria-label={ui.handleStatus}
                  >
                    <option value="pending">{ui.statusPending}</option>
                    <option value="processing">{ui.statusProcessing}</option>
                    <option value="resolved">{ui.statusResolved}</option>
                  </select>
                </span>
              </div>
            </div>
            <p style={{ marginTop: 12, fontSize: 12, color: 'var(--text-dim)' }}>
              {selectedAlert.description}
            </p>
          </div>
        </aside>

        <section className="center-column">
          <div className="tabs" role="tablist">
            {topTabs.map((t) => (
              <button
                key={t.id}
                role="tab"
                aria-selected={topTab === t.id}
                className={`tab ${topTab === t.id ? 'active' : ''}`}
                onClick={() => setTopTab(t.id)}
              >
                {t.label}
              </button>
            ))}
          </div>

          {(topTab === 'map' || topTab === 'flight') && (
            <>
              <div className="mission-bar">
                <div className="mission-top">
                  <div className="mission-name">{mission.name}</div>
                  <span className={`status-pill ${mission.status}`}>
                    {statusLabel(ui, mission.status)}
                  </span>
                </div>
                <div className="stat-row">
                  <div className="stat-chip danger">
                    <div className="num">{mission.alerts}</div>
                    <div className="lbl">{ui.alertEvents}</div>
                  </div>
                  <div className="stat-chip info">
                    <div className="num">{mission.photos}</div>
                    <div className="lbl">{ui.photos}</div>
                  </div>
                  <div className="stat-chip success">
                    <div className="num">{mission.videos}</div>
                    <div className="lbl">{ui.videos}</div>
                  </div>
                  <div className="stat-chip gold">
                    <div className="num">{mission.reports}</div>
                    <div className="lbl">{ui.flightReports}</div>
                  </div>
                </div>
                <div className="mission-meta">
                  <span>
                    {ui.metaScene}：<strong>{mission.scene}</strong>
                  </span>
                  <span>
                    {ui.metaDevice}：<strong>{mission.device}</strong>
                  </span>
                  <span>
                    {ui.metaRoute}：<strong>{mission.routeName}</strong>
                  </span>
                  <span>
                    {ui.metaAlgorithm}：<strong>{mission.algorithm}</strong>
                  </span>
                  <span>
                    {ui.metaDuration}：<strong>{mission.duration}</strong>
                  </span>
                  <span>
                    {ui.metaWindow}：
                    <strong>
                      {mission.startTime} ~ {mission.endTime}
                    </strong>
                  </span>
                </div>
              </div>
              <div className="panel map-panel">
                <MapCanvas
                  mission={mission}
                  devices={sceneDevices}
                  alerts={sceneAlerts}
                  selectedAlertId={selectedAlertId}
                  onSelectAlert={setSelectedAlertId}
                  locale={locale}
                />
              </div>
            </>
          )}

          {topTab === 'alerts' && (
            <div className="content-view" data-testid="alerts-view">
              <div className="filter-tabs">
                {(
                  [
                    ['all', ui.filterAll],
                    ['pending', ui.statusPending],
                    ['processing', ui.statusProcessing],
                    ['resolved', ui.statusResolved],
                  ] as const
                ).map(([id, label]) => (
                  <button
                    key={id}
                    className={alertFilter === id ? 'active' : ''}
                    onClick={() => setAlertFilter(id)}
                  >
                    {label}
                  </button>
                ))}
              </div>
              <div className="alert-list">
                {filteredAlerts.map((a) => (
                  <button
                    key={a.id}
                    className={`alert-card ${selectedAlertId === a.id ? 'active' : ''}`}
                    onClick={() => setSelectedAlertId(a.id)}
                  >
                    <div className={`bar ${a.level}`} />
                    <div>
                      <h4>{a.name}</h4>
                      <p>{a.description}</p>
                      <p style={{ marginTop: 4 }}>
                        {a.source} · {a.time}
                      </p>
                    </div>
                    <span className={`status-pill ${a.status}`}>{statusLabel(ui, a.status)}</span>
                  </button>
                ))}
              </div>
            </div>
          )}

          {topTab === 'devices' && (
            <div className="content-view" data-testid="devices-view">
              <div className="metric-grid" style={{ gridTemplateColumns: 'repeat(4, 1fr)' }}>
                <div className="metric">
                  <div className="n">{kpiStats.todayFlights}</div>
                  <div className="l">{ui.todayFlights}</div>
                </div>
                <div className="metric">
                  <div className="n">{kpiStats.todayMileage}</div>
                  <div className="l">{ui.flightMileage}</div>
                </div>
                <div className="metric">
                  <div className="n">{kpiStats.todayFlightMin}</div>
                  <div className="l">{ui.flightMinutes}</div>
                </div>
                <div className="metric">
                  <div className="n">{kpiStats.docksOnline}</div>
                  <div className="l">{ui.docksOnline}</div>
                </div>
              </div>
              <div className="device-grid">
                {devices.map((d) => (
                  <div key={d.id} className="device-card">
                    <header>
                      <span>{d.name}</span>
                      <span className={`status-pill ${d.status}`}>{statusLabel(ui, d.status)}</span>
                    </header>
                    <div className="kv-list">
                      <div className="kv-row">
                        <span className="k">{ui.deviceId}</span>
                        <span className="v">{d.id}</span>
                      </div>
                      <div className="kv-row">
                        <span className="k">{ui.deviceLocation}</span>
                        <span className="v">{d.location}</span>
                      </div>
                    </div>
                    {typeof d.battery === 'number' && (
                      <div className={`battery ${d.battery < 30 ? 'low' : ''}`}>
                        <span style={{ width: `${d.battery}%` }} />
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {topTab === 'linkage' && (
            <div className="content-view" data-testid="linkage-view">
              <h3 className="section-title">{ui.linkageTitle}</h3>
              <div className="split-2">
                <div className="steps">
                  {linkageSteps.map((s) => (
                    <div key={s.step} className="step">
                      <div className="idx">{s.step}</div>
                      <div>
                        <h5>{s.title}</h5>
                        <p>{s.detail}</p>
                      </div>
                    </div>
                  ))}
                </div>
                <div>
                  <div className="panel" style={{ height: '100%' }}>
                    <div className="panel-title">
                      <span>{ui.currentPlan}</span>
                      <span className="tag">{ui.humanConfirm}</span>
                    </div>
                    <div className="panel-body">
                      <p style={{ fontSize: 13, marginBottom: 12 }}>{ui.linkageIntro}</p>
                      <div className="kv-list">
                        <div className="kv-row">
                          <span className="k">{ui.triggerEvent}</span>
                          <span className="v">{ui.triggerEventValue}</span>
                        </div>
                        <div className="kv-row">
                          <span className="k">{ui.airUnit}</span>
                          <span className="v">{ui.airUnitValue}</span>
                        </div>
                        <div className="kv-row">
                          <span className="k">{ui.groundUnit}</span>
                          <span className="v">{ui.groundUnitValue}</span>
                        </div>
                        <div className="kv-row">
                          <span className="k">{ui.comms}</span>
                          <span className="v">{ui.commsValue}</span>
                        </div>
                        <div className="kv-row">
                          <span className="k">{ui.disposition}</span>
                          <span className="v">{ui.dispositionValue}</span>
                        </div>
                      </div>
                      <div className="principle-box">{ui.principleCore}</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {topTab === 'architecture' && (
            <div className="content-view" data-testid="architecture-view">
              <h3 className="section-title">{ui.architectureTitle}</h3>
              <div className="layer-list">
                {architectureLayers.map((l) => (
                  <div key={l.layer} className="layer-item">
                    <div className="layer">{l.layer}</div>
                    <h5>{l.name}</h5>
                    <p>{l.capability}</p>
                  </div>
                ))}
              </div>
              <div className="principle-box">{ui.architecturePoc}</div>
            </div>
          )}
        </section>

        <aside className="panel" data-testid="right-panel">
          <div className="panel-title">
            <span>{ui.todayTasks}</span>
            <span className="tag">
              {formatTemplate(ui.tasksPendingDone, {
                pending: kpiStats.pendingTasks,
                done: kpiStats.doneTasks,
              })}
            </span>
          </div>
          <div className="panel-body">
            <div className="metric-grid">
              <div className="metric">
                <div className="n">2</div>
                <div className="l">{ui.immediate}</div>
              </div>
              <div className="metric">
                <div className="n">3</div>
                <div className="l">{ui.scheduled}</div>
              </div>
              <div className="metric">
                <div className="n">1</div>
                <div className="l">{ui.cyclic}</div>
              </div>
            </div>

            <h3 className="section-title">{ui.routeInfo}</h3>
            <div className="kv-list" style={{ marginBottom: 16 }}>
              <div className="kv-row">
                <span className="k">{ui.routeName}</span>
                <span className="v">{mission.routeName}</span>
              </div>
              <div className="kv-row">
                <span className="k">{ui.flightSpeed}</span>
                <span className="v">{mission.speed} m/s</span>
              </div>
              <div className="kv-row">
                <span className="k">{ui.climbSpeed}</span>
                <span className="v">{mission.climbSpeed} m/s</span>
              </div>
              <div className="kv-row">
                <span className="k">{ui.flightAltitude}</span>
                <span className="v">{mission.altitude} m</span>
              </div>
              <div className="kv-row">
                <span className="k">{ui.routeDistance}</span>
                <span className="v">{mission.distance} km</span>
              </div>
              <div className="kv-row">
                <span className="k">{ui.waypointCount}</span>
                <span className="v">{mission.waypoints.length}</span>
              </div>
            </div>

            <h3 className="section-title">
              {ui.waypointInfo} · #{activeWaypoint.id}
            </h3>
            <div className="kv-list">
              <div className="kv-row">
                <span className="k">{ui.gimbalPitch}</span>
                <span className="v">{activeWaypoint.gimbalPitch}°</span>
              </div>
              <div className="kv-row">
                <span className="k">{ui.waypointAction}</span>
                <span className="v">{activeWaypoint.action}</span>
              </div>
              <div className="kv-row">
                <span className="k">{ui.coords}</span>
                <span className="v">
                  {activeWaypoint.coords[0].toFixed(6)}, {activeWaypoint.coords[1].toFixed(6)}
                </span>
              </div>
            </div>

            <h3 className="section-title" style={{ marginTop: 16 }}>
              {ui.todayAlarms}
            </h3>
            <div className="alert-list">
              {sceneAlerts.slice(0, 3).map((a) => (
                <button
                  key={a.id}
                  className={`alert-card ${selectedAlertId === a.id ? 'active' : ''}`}
                  onClick={() => {
                    setSelectedAlertId(a.id)
                    setTopTab('alerts')
                  }}
                >
                  <div className={`bar ${a.level}`} />
                  <div>
                    <h4>{a.name}</h4>
                    <p>{a.time}</p>
                  </div>
                </button>
              ))}
            </div>
          </div>
        </aside>
      </main>

      <nav className="bottom-nav" aria-label={ui.mainModules}>
        {bottomModules.map((m) => (
          <button
            key={m.id}
            className={`nav-btn ${module === m.id ? 'active' : ''}`}
            onClick={() => setModule(m.id)}
          >
            <div className="icon">{m.icon}</div>
            <span>{m.label}</span>
          </button>
        ))}
      </nav>
    </div>
  )
}
