import { useEffect, useMemo, useState } from 'react'
import { MapCanvas } from './components/MapCanvas'
import {
  alerts as allAlerts,
  architectureLayers,
  campMission,
  devices,
  kpiStats,
  linkageSteps,
  villaMission,
  type AlertItem,
  type AlertStatus,
  type Mission,
} from './data/mockData'

type TopTab = 'map' | 'alerts' | 'devices' | 'linkage' | 'flight' | 'architecture'
type BottomModule = 'ops' | 'alerts' | 'airground' | 'assets' | 'solution'
type SceneMode = 'camp' | 'villa'

const topTabs: { id: TopTab; label: string }[] = [
  { id: 'map', label: '地图' },
  { id: 'alerts', label: '预警线索' },
  { id: 'devices', label: '设备' },
  { id: 'linkage', label: '空地联动' },
  { id: 'flight', label: '飞行成果' },
  { id: 'architecture', label: '五层架构' },
]

const bottomModules: { id: BottomModule; label: string; icon: string }[] = [
  { id: 'ops', label: '综合态势', icon: '◎' },
  { id: 'alerts', label: '预警中心', icon: '⚠' },
  { id: 'airground', label: '空地协同', icon: '✈' },
  { id: 'assets', label: '资产设备', icon: '▣' },
  { id: 'solution', label: '方案能力', icon: '◆' },
]

function formatNow() {
  const d = new Date()
  const pad = (n: number) => String(n).padStart(2, '0')
  return {
    time: `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`,
    date: `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`,
  }
}

function statusLabel(status: string) {
  const map: Record<string, string> = {
    pending: '待处理',
    processing: '处理中',
    resolved: '已处理',
    executing: '执行中',
    success: '执行成功',
    online: '在线',
    patrol: '巡逻中',
    charging: '充电中',
    offline: '离线',
    standby: '待命',
  }
  return map[status] ?? status
}

export default function App() {
  const [clock, setClock] = useState(formatNow)
  const [scene, setScene] = useState<SceneMode>('camp')
  const [topTab, setTopTab] = useState<TopTab>('flight')
  const [module, setModule] = useState<BottomModule>('ops')
  const [alertFilter, setAlertFilter] = useState<'all' | AlertStatus>('all')
  const [selectedAlertId, setSelectedAlertId] = useState(allAlerts[0].id)
  const [alertStatus, setAlertStatus] = useState<Record<string, AlertStatus>>(
    Object.fromEntries(allAlerts.map((a) => [a.id, a.status])),
  )

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

  const mission: Mission = scene === 'camp' ? campMission : villaMission
  const sceneAlerts = useMemo(
    () => allAlerts.filter((a) => (scene === 'camp' ? a.scene === 'camp' : a.scene !== 'camp')),
    [scene],
  )
  const selectedAlert: AlertItem =
    allAlerts.find((a) => a.id === selectedAlertId) ?? allAlerts[0]

  const filteredAlerts = useMemo(() => {
    const list = sceneAlerts.map((a) => ({ ...a, status: alertStatus[a.id] ?? a.status }))
    if (alertFilter === 'all') return list
    return list.filter((a) => a.status === alertFilter)
  }, [sceneAlerts, alertFilter, alertStatus])

  const sceneDevices = useMemo(() => {
    if (scene === 'camp') {
      return devices.filter((d) => !d.location.includes('Karen') && !d.location.includes('别墅'))
    }
    return devices.filter(
      (d) => d.location.includes('Karen') || d.location.includes('别墅') || d.type === 'camera',
    )
  }, [scene])

  const activeWaypoint = mission.waypoints[3] ?? mission.waypoints[0]

  return (
    <div className="app-shell" data-testid="africa-security-demo">
      <header className="header">
        <div className="header-left">
          <div className="header-clock">{clock.time}</div>
          <div className="header-date">{clock.date} · Kenya Ops</div>
        </div>
        <div className="header-title">
          <h1>非洲安防空地一体综合管理平台</h1>
          <p>Africa Air-Ground Integrated Security Platform</p>
        </div>
        <div className="header-right">
          <div className="tabs" role="group" aria-label="场景切换">
            <button
              className={`tab ${scene === 'camp' ? 'active' : ''}`}
              onClick={() => {
                setScene('camp')
                setSelectedAlertId('ALT-20261013-88421')
              }}
            >
              工程营地
            </button>
            <button
              className={`tab ${scene === 'villa' ? 'active' : ''}`}
              onClick={() => {
                setScene('villa')
                setSelectedAlertId('ALT-20261013-88390')
              }}
            >
              高端别墅
            </button>
          </div>
          <div className="user-chip">
            <div className="user-avatar">A</div>
            <span>admin · 安全运营</span>
          </div>
        </div>
      </header>

      <main className="main-stage">
        <aside className="panel" data-testid="left-panel">
          <div className="panel-title">
            <span>预警详情</span>
            <span className="tag">AI + 多源融合</span>
          </div>
          <div className="panel-body">
            <div className="ring-wrap">
              <div className="ring">
                <div>
                  <strong>{kpiStats.dronesOnline}</strong>
                  <span>无人机在线</span>
                </div>
              </div>
            </div>
            <div className="metric-grid">
              <div className="metric">
                <div className="n">{kpiStats.dogsOnline}</div>
                <div className="l">机器狗</div>
              </div>
              <div className="metric">
                <div className="n">{kpiStats.camerasOnline}</div>
                <div className="l">感知点位</div>
              </div>
              <div className="metric">
                <div className="n">{kpiStats.pendingAlerts}</div>
                <div className="l">待处理</div>
              </div>
            </div>

            <h3 className="section-title">{selectedAlert.name}</h3>
            <div className="thumb-row">
              {selectedAlert.thumbnails.map((t) => (
                <div key={t} className="thumb">
                  {t === 'thermal' ? '热成像' : '光学取证'}
                </div>
              ))}
            </div>
            <div className="kv-list">
              <div className="kv-row"><span className="k">预警编号</span><span className="v">{selectedAlert.id}</span></div>
              <div className="kv-row"><span className="k">违法类型</span><span className="v">{selectedAlert.type}</span></div>
              <div className="kv-row"><span className="k">地点</span><span className="v">{selectedAlert.location}</span></div>
              <div className="kv-row">
                <span className="k">坐标</span>
                <span className="v">{selectedAlert.coords[0].toFixed(6)}, {selectedAlert.coords[1].toFixed(6)}</span>
              </div>
              <div className="kv-row"><span className="k">报警时间</span><span className="v">{selectedAlert.time}</span></div>
              <div className="kv-row"><span className="k">报警来源</span><span className="v">{selectedAlert.source}</span></div>
              <div className="kv-row">
                <span className="k">处理状态</span>
                <span className="v">
                  <select
                    className="select"
                    value={alertStatus[selectedAlert.id]}
                    onChange={(e) =>
                      setAlertStatus((prev) => ({
                        ...prev,
                        [selectedAlert.id]: e.target.value as AlertStatus,
                      }))
                    }
                    aria-label="处理状态"
                  >
                    <option value="pending">待处理</option>
                    <option value="processing">处理中</option>
                    <option value="resolved">已处理</option>
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
                  <span className={`status-pill ${mission.status}`}>{statusLabel(mission.status)}</span>
                </div>
                <div className="stat-row">
                  <div className="stat-chip danger"><div className="num">{mission.alerts}</div><div className="lbl">预警事件</div></div>
                  <div className="stat-chip info"><div className="num">{mission.photos}</div><div className="lbl">拍摄照片</div></div>
                  <div className="stat-chip success"><div className="num">{mission.videos}</div><div className="lbl">拍摄视频</div></div>
                  <div className="stat-chip gold"><div className="num">{mission.reports}</div><div className="lbl">飞行报告</div></div>
                </div>
                <div className="mission-meta">
                  <span>场景：<strong>{mission.scene}</strong></span>
                  <span>设备：<strong>{mission.device}</strong></span>
                  <span>航线：<strong>{mission.routeName}</strong></span>
                  <span>算法：<strong>{mission.algorithm}</strong></span>
                  <span>时长：<strong>{mission.duration}</strong></span>
                  <span>时段：<strong>{mission.startTime} ~ {mission.endTime}</strong></span>
                </div>
              </div>
              <div className="panel map-panel">
                <MapCanvas
                  mission={mission}
                  devices={sceneDevices}
                  alerts={sceneAlerts}
                  selectedAlertId={selectedAlertId}
                  onSelectAlert={setSelectedAlertId}
                />
              </div>
            </>
          )}

          {topTab === 'alerts' && (
            <div className="content-view" data-testid="alerts-view">
              <div className="filter-tabs">
                {([
                  ['all', '全部'],
                  ['pending', '待处理'],
                  ['processing', '处理中'],
                  ['resolved', '已处理'],
                ] as const).map(([id, label]) => (
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
                      <p style={{ marginTop: 4 }}>{a.source} · {a.time}</p>
                    </div>
                    <span className={`status-pill ${a.status}`}>{statusLabel(a.status)}</span>
                  </button>
                ))}
              </div>
            </div>
          )}

          {topTab === 'devices' && (
            <div className="content-view" data-testid="devices-view">
              <div className="metric-grid" style={{ gridTemplateColumns: 'repeat(4, 1fr)' }}>
                <div className="metric"><div className="n">{kpiStats.todayFlights}</div><div className="l">今日飞行次数</div></div>
                <div className="metric"><div className="n">{kpiStats.todayMileage}</div><div className="l">飞行里程 km</div></div>
                <div className="metric"><div className="n">{kpiStats.todayFlightMin}</div><div className="l">飞行时长 min</div></div>
                <div className="metric"><div className="n">{kpiStats.docksOnline}</div><div className="l">机巢在线</div></div>
              </div>
              <div className="device-grid">
                {devices.map((d) => (
                  <div key={d.id} className="device-card">
                    <header>
                      <span>{d.name}</span>
                      <span className={`status-pill ${d.status}`}>{statusLabel(d.status)}</span>
                    </header>
                    <div className="kv-list">
                      <div className="kv-row"><span className="k">编号</span><span className="v">{d.id}</span></div>
                      <div className="kv-row"><span className="k">位置</span><span className="v">{d.location}</span></div>
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
              <h3 className="section-title">系统联动闭环（摄像头 → AI → 无人机 → 机器狗 → 指挥中心）</h3>
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
                    <div className="panel-title"><span>当前预案</span><span className="tag">人工最终确认</span></div>
                    <div className="panel-body">
                      <p style={{ fontSize: 13, marginBottom: 12 }}>
                        真正的产品价值来自设备联动：无人机负责空中大范围，机器狗负责地面近距离；
                        声光驱离（爆闪+喊话+警报）作为第一响应，不做武器化自动攻击。
                      </p>
                      <div className="kv-list">
                        <div className="kv-row"><span className="k">触发事件</span><span className="v">营地外围人员入侵</span></div>
                        <div className="kv-row"><span className="k">空中单元</span><span className="v">UAV-01 快速起飞侦察</span></div>
                        <div className="kv-row"><span className="k">地面单元</span><span className="v">RD-01 近距接近驱离</span></div>
                        <div className="kv-row"><span className="k">通信保障</span><span className="v">Starlink 地面中继回传</span></div>
                        <div className="kv-row"><span className="k">处置原则</span><span className="v">人在回路，最终处置权在人</span></div>
                      </div>
                      <div className="principle-box">
                        核心定位：不是“机器狗销售”，而是面向高风险客户的智能安防解决方案 —
                        设备 + AI + 通信 + 人员 + 情报 的系统联动。
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {topTab === 'architecture' && (
            <div className="content-view" data-testid="architecture-view">
              <h3 className="section-title">五层架构 · 安全能力提供商</h3>
              <div className="layer-list">
                {architectureLayers.map((l) => (
                  <div key={l.layer} className="layer-item">
                    <div className="layer">{l.layer}</div>
                    <h5>{l.name}</h5>
                    <p>{l.capability}</p>
                  </div>
                ))}
              </div>
              <div className="principle-box">
                POC优先场景：高风险工程营地限定区域智能巡逻，或高端别墅夜间外围巡逻。
                用最小成本验证“客户→痛点→方案→报价→付款→交付→反馈”闭环。
              </div>
            </div>
          )}
        </section>

        <aside className="panel" data-testid="right-panel">
          <div className="panel-title">
            <span>今日任务</span>
            <span className="tag">待执行 {kpiStats.pendingTasks} / 已执行 {kpiStats.doneTasks}</span>
          </div>
          <div className="panel-body">
            <div className="metric-grid">
              <div className="metric"><div className="n">2</div><div className="l">立即执行</div></div>
              <div className="metric"><div className="n">3</div><div className="l">定时模式</div></div>
              <div className="metric"><div className="n">1</div><div className="l">循环模式</div></div>
            </div>

            <h3 className="section-title">航线信息</h3>
            <div className="kv-list" style={{ marginBottom: 16 }}>
              <div className="kv-row"><span className="k">航线名称</span><span className="v">{mission.routeName}</span></div>
              <div className="kv-row"><span className="k">飞行速度</span><span className="v">{mission.speed} m/s</span></div>
              <div className="kv-row"><span className="k">上升速度</span><span className="v">{mission.climbSpeed} m/s</span></div>
              <div className="kv-row"><span className="k">飞行高度</span><span className="v">{mission.altitude} m</span></div>
              <div className="kv-row"><span className="k">航线里程</span><span className="v">{mission.distance} km</span></div>
              <div className="kv-row"><span className="k">航点数量</span><span className="v">{mission.waypoints.length}</span></div>
            </div>

            <h3 className="section-title">航点信息 · #{activeWaypoint.id}</h3>
            <div className="kv-list">
              <div className="kv-row"><span className="k">云台俯仰</span><span className="v">{activeWaypoint.gimbalPitch}°</span></div>
              <div className="kv-row"><span className="k">航点动作</span><span className="v">{activeWaypoint.action}</span></div>
              <div className="kv-row">
                <span className="k">坐标</span>
                <span className="v">{activeWaypoint.coords[0].toFixed(6)}, {activeWaypoint.coords[1].toFixed(6)}</span>
              </div>
            </div>

            <h3 className="section-title" style={{ marginTop: 16 }}>今日告警</h3>
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

      <nav className="bottom-nav" aria-label="主模块">
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
