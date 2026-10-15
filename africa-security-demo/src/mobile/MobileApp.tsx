import { useMemo, useState } from 'react'
import { getAlerts, getDevices, kpiStats } from '../data/mockData'
import { useLocale } from '../i18n/LocaleContext'
import { statusLabel } from '../i18n/ui'
import { LiveView } from './LiveView'
import './mobile.css'

type MobileTab = 'home' | 'alerts' | 'live' | 'devices'

export default function MobileApp() {
  const { locale, setLocale, ui } = useLocale()
  const [tab, setTab] = useState<MobileTab>('live')
  const alerts = useMemo(() => getAlerts(locale), [locale])
  const devices = useMemo(() => getDevices(locale), [locale])
  const pending = alerts.filter((a) => a.status === 'pending')

  const titleMap: Record<MobileTab, string> = {
    home: ui.mobileHome,
    alerts: ui.mobileAlerts,
    live: ui.mobileLiveTitle,
    devices: ui.mobileDevices,
  }

  return (
    <div className="mobile-stage" data-testid="mobile-app">
      <div className="mobile-shell">
        <header className="mobile-topbar">
          <div>
            <h1>{titleMap[tab]}</h1>
            <div className="sub">{ui.mobileOpsSummary}</div>
          </div>
          <div className="mobile-top-actions">
            <div className="lang-switch" role="group" aria-label={ui.langSwitch}>
              <button
                type="button"
                className={`lang-btn ${locale === 'zh' ? 'active' : ''}`}
                onClick={() => setLocale('zh')}
              >
                中文
              </button>
              <button
                type="button"
                className={`lang-btn ${locale === 'en' ? 'active' : ''}`}
                onClick={() => setLocale('en')}
              >
                EN
              </button>
            </div>
          </div>
        </header>

        <div className="mobile-body">
          {tab === 'home' && (
            <div data-testid="mobile-home">
              <div className="m-card">
                <h3>{ui.mobileGreeting}</h3>
                <p className="demo-note" style={{ marginBottom: 10 }}>
                  {ui.mobileOpsSummary}
                </p>
                <div className="m-stats">
                  <div className="m-stat">
                    <div className="n">{kpiStats.pendingAlerts}</div>
                    <div className="l">{ui.mobilePendingAlerts}</div>
                  </div>
                  <div className="m-stat">
                    <div className="n">{kpiStats.dronesOnline + kpiStats.dogsOnline}</div>
                    <div className="l">{ui.mobileActiveUnits}</div>
                  </div>
                </div>
              </div>

              <div className="m-card">
                <h3>{ui.mobileQuickActions}</h3>
                <button type="button" className="m-btn" onClick={() => setTab('live')}>
                  {ui.mobileOpenLive}
                </button>
                <div style={{ height: 8 }} />
                <button type="button" className="m-btn ghost">
                  {ui.mobileActionDeterrence}
                </button>
                <div style={{ height: 8 }} />
                <button type="button" className="m-btn ghost">
                  {ui.mobileActionDispatch}
                </button>
              </div>

              <div className="m-card">
                <h3>{ui.todayAlarms}</h3>
                {pending.slice(0, 2).map((a) => (
                  <button
                    key={a.id}
                    type="button"
                    className="m-alert"
                    onClick={() => setTab('alerts')}
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
          )}

          {tab === 'alerts' && (
            <div data-testid="mobile-alerts">
              {alerts.map((a) => (
                <button
                  key={a.id}
                  type="button"
                  className="m-alert"
                  onClick={() => setTab('live')}
                >
                  <div className={`bar ${a.level}`} />
                  <div>
                    <h4>{a.name}</h4>
                    <p>{a.description}</p>
                    <p style={{ marginTop: 4 }}>
                      {statusLabel(ui, a.status)} · {a.time}
                    </p>
                  </div>
                </button>
              ))}
            </div>
          )}

          {tab === 'live' && <LiveView />}

          {tab === 'devices' && (
            <div data-testid="mobile-devices">
              {devices.map((d) => (
                <div key={d.id} className="m-card">
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
                    <strong style={{ fontSize: 13 }}>{d.name}</strong>
                    <span className={`status-pill ${d.status}`}>{statusLabel(ui, d.status)}</span>
                  </div>
                  <p className="demo-note" style={{ marginTop: 6 }}>
                    {d.id} · {d.location}
                    {typeof d.battery === 'number' ? ` · ${d.battery}%` : ''}
                  </p>
                  {(d.id === 'UAV-01' || d.id === 'RD-01') && (
                    <button
                      type="button"
                      className="m-btn"
                      style={{ marginTop: 8 }}
                      onClick={() => setTab('live')}
                    >
                      {ui.mobileOpenLive}
                    </button>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>

        <nav className="mobile-tabbar" aria-label={ui.mainModules}>
          {(
            [
              ['home', ui.mobileHome, '⌂'],
              ['alerts', ui.mobileAlerts, '⚠'],
              ['live', ui.mobileLive, '◉'],
              ['devices', ui.mobileDevices, '▣'],
            ] as const
          ).map(([id, label, icon]) => (
            <button
              key={id}
              type="button"
              className={`mobile-tab ${tab === id ? 'active' : ''}`}
              onClick={() => setTab(id)}
            >
              <div className="ico">{icon}</div>
              <span>{label}</span>
            </button>
          ))}
        </nav>
      </div>
    </div>
  )
}
