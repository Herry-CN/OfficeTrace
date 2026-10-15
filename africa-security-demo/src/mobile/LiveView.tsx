import { useEffect, useMemo, useRef, useState } from 'react'
import { getDevices } from '../data/mockData'
import { useLocale } from '../i18n/LocaleContext'
import { statusLabel } from '../i18n/ui'

type FeedId = 'UAV-01' | 'RD-01'
type ViewMode = 'optical' | 'thermal' | 'split'

type ChatMsg = {
  id: string
  from: 'you' | 'device'
  text: string
  time: string
}

function nowLabel() {
  const d = new Date()
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
}

export function LiveView() {
  const { locale, ui } = useLocale()
  const devices = useMemo(() => getDevices(locale), [locale])
  const drone = devices.find((d) => d.id === 'UAV-01')!
  const dog = devices.find((d) => d.id === 'RD-01')!

  const [feed, setFeed] = useState<FeedId>('RD-01')
  const [viewMode, setViewMode] = useState<ViewMode>('optical')
  const [talking, setTalking] = useState(false)
  const [muted, setMuted] = useState(false)
  const [siren, setSiren] = useState(false)
  const [strobe, setStrobe] = useState(false)
  const [latency, setLatency] = useState(180)
  const [messages, setMessages] = useState<ChatMsg[]>([])
  const talkStarted = useRef<number | null>(null)
  const replyTimer = useRef<number | null>(null)

  const active = feed === 'UAV-01' ? drone : dog
  const isDrone = feed === 'UAV-01'

  useEffect(() => {
    const t = window.setInterval(() => {
      setLatency(160 + Math.floor(Math.random() * 80))
    }, 1800)
    return () => window.clearInterval(t)
  }, [])

  useEffect(() => {
    return () => {
      if (replyTimer.current) window.clearTimeout(replyTimer.current)
    }
  }, [])

  const pushMessage = (from: ChatMsg['from'], text: string) => {
    setMessages((prev) => [
      ...prev.slice(-20),
      { id: `${Date.now()}-${Math.random()}`, from, text, time: nowLabel() },
    ])
  }

  const startTalk = () => {
    if (muted) return
    setTalking(true)
    talkStarted.current = Date.now()
  }

  const endTalk = () => {
    if (!talking) return
    setTalking(false)
    const phrases =
      locale === 'zh'
        ? [
            '注意，此处为受控安防区域，请立即离开。',
            '已发现异常活动，请停留并配合现场确认。',
            '安保单元正在接近，请保持原地。',
          ]
        : [
            'Attention: controlled security zone. Leave immediately.',
            'Abnormal activity detected. Stay and wait for confirmation.',
            'Security unit approaching. Remain where you are.',
          ]
    const said = phrases[Math.floor(Math.random() * phrases.length)]
    pushMessage('you', said)

    if (replyTimer.current) window.clearTimeout(replyTimer.current)
    replyTimer.current = window.setTimeout(() => {
      const replies =
        locale === 'zh'
          ? [
              '收到，图传正常，正在保持锁定。',
              '现场热源仍在移动，建议继续驱离。',
              '对讲清晰，等待指挥中心下一步指令。',
            ]
          : [
              'Copy. Video link stable, maintaining lock.',
              'Heat source still moving. Suggest continued deterrence.',
              'Intercom clear. Awaiting next command.',
            ]
      pushMessage('device', replies[Math.floor(Math.random() * replies.length)])
    }, 900)
  }

  const feedCard = (id: FeedId, title: string, deviceName: string, meta: string) => (
    <button
      type="button"
      className={`feed-chip ${feed === id ? 'active' : ''}`}
      onClick={() => setFeed(id)}
      aria-pressed={feed === id}
    >
      <strong>{title}</strong>
      <span>
        {deviceName} · {meta}
      </span>
    </button>
  )

  const feedSrc = (kind: 'optical' | 'thermal', source: FeedId) => {
    if (source === 'RD-01') {
      return kind === 'thermal' ? '/feeds/robot-dog-thermal.gif' : '/feeds/robot-dog-live.gif'
    }
    return kind === 'thermal' ? '/feeds/drone-thermal.gif' : '/feeds/drone-live.gif'
  }

  const renderFeed = (kind: 'optical' | 'thermal', source: FeedId) => {
    const cls = [
      'video-feed',
      'has-stream',
      kind === 'thermal' ? 'thermal' : '',
      source === 'RD-01' ? 'dog' : '',
    ]
      .filter(Boolean)
      .join(' ')
    return (
      <div className={cls} data-testid={`feed-${source}-${kind}`}>
        <img
          className="video-stream"
          src={feedSrc(kind, source)}
          alt={`${source} ${kind} live feed`}
          draggable={false}
        />
        <div className="video-hud">
          <div className="hud-row">
            <span className="live-pill">{ui.mobileLiveBadge}</span>
            <span className="hud-chip">
              {ui.mobileLatency} {latency}ms
            </span>
          </div>
          <div className="crosshair" />
          <div className="hud-row">
            <span className="hud-chip">
              {source} · {kind === 'thermal' ? ui.mobileThermal : ui.mobileOptical}
            </span>
            <span className="hud-chip">
              {ui.mobileBattery} {source === 'UAV-01' ? drone.battery : dog.battery}%
            </span>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="live-page" data-testid="mobile-live">
      <div className="m-card" style={{ marginBottom: 0 }}>
        <h3>{ui.mobileSelectFeed}</h3>
        <div className="feed-switch">
          {feedCard(
            'UAV-01',
            ui.mobileFeedDrone,
            drone.name,
            `${statusLabel(ui, drone.status)} · ${drone.battery}%`,
          )}
          {feedCard(
            'RD-01',
            ui.mobileFeedDog,
            dog.name,
            `${statusLabel(ui, dog.status)} · ${dog.battery}%`,
          )}
        </div>
      </div>

      <div className={`video-stage ${viewMode === 'split' ? 'split' : ''}`} data-testid="video-stage">
        {viewMode === 'split' ? (
          <>
            {renderFeed('optical', feed)}
            {renderFeed('thermal', feed)}
          </>
        ) : (
          renderFeed(viewMode, feed)
        )}
      </div>

      <div className="mode-row" role="group" aria-label="view-mode">
        <button
          type="button"
          className={viewMode === 'optical' ? 'active' : ''}
          onClick={() => setViewMode('optical')}
        >
          {ui.mobileOptical}
        </button>
        <button
          type="button"
          className={viewMode === 'thermal' ? 'active' : ''}
          onClick={() => setViewMode('thermal')}
        >
          {ui.mobileThermal}
        </button>
        <button
          type="button"
          className={viewMode === 'split' ? 'active' : ''}
          onClick={() => setViewMode('split')}
        >
          {ui.mobileSplit}
        </button>
      </div>

      <div className="m-stats">
        <div className="m-stat">
          <div className="n">{isDrone ? '45' : '1.2'}</div>
          <div className="l">{isDrone ? `${ui.mobileAltitude} m` : `${ui.mobileSpeed} m/s`}</div>
        </div>
        <div className="m-stat">
          <div className="n">{isDrone ? '8' : '62'}</div>
          <div className="l">{isDrone ? `${ui.mobileSpeed} m/s` : `${ui.mobileBattery} %`}</div>
        </div>
      </div>

      <div className="action-row">
        <button
          type="button"
          className={siren ? 'active' : ''}
          onClick={() => setSiren((v) => !v)}
        >
          {ui.mobileSiren}
        </button>
        <button
          type="button"
          className={strobe ? 'active' : ''}
          onClick={() => setStrobe((v) => !v)}
        >
          {ui.mobileSpotlight}
        </button>
        <button
          type="button"
          onClick={() =>
            pushMessage(
              'device',
              locale === 'zh' ? '已保存取证截图。' : 'Evidence snapshot saved.',
            )
          }
        >
          {ui.mobileSnapshot}
        </button>
      </div>

      <div className="m-card intercom-box" data-testid="intercom-panel">
        <h3>
          {ui.mobileIntercom} · {ui.mobileChannel}: {active.id}
        </h3>
        <div className="chat-log" data-testid="chat-log">
          {messages.length === 0 ? (
            <div className="chat-empty">{ui.mobileChatEmpty}</div>
          ) : (
            messages.map((m) => (
              <div key={m.id} className={`chat-item ${m.from}`}>
                <span className="who">{m.from === 'you' ? ui.mobileYou : ui.mobileDeviceSaid}</span>
                <span>
                  [{m.time}] {m.text}
                </span>
              </div>
            ))
          )}
        </div>

        <div className="ptt-wrap">
          {talking && (
            <div className="ptt-wave" aria-hidden>
              <span /><span /><span /><span /><span />
            </div>
          )}
          <button
            type="button"
            className={`ptt-btn ${talking ? 'talking' : ''}`}
            data-testid="ptt-button"
            aria-pressed={talking}
            onPointerDown={(e) => {
              try {
                e.currentTarget.setPointerCapture?.(e.pointerId)
              } catch {
                // jsdom may not support pointer capture
              }
              startTalk()
            }}
            onPointerUp={endTalk}
            onPointerCancel={endTalk}
            onPointerLeave={() => {
              if (talking) endTalk()
            }}
          >
            {talking ? ui.mobileTalking : ui.mobilePtt}
          </button>
          <div className="ptt-hint">{ui.mobilePttHint}</div>
        </div>

        <div className="action-row">
          <button type="button" className={!muted ? 'active' : ''} onClick={() => setMuted(false)}>
            {ui.mobileSpeakerOn}
          </button>
          <button type="button" className={muted ? 'active' : ''} onClick={() => setMuted(true)}>
            {muted ? ui.mobileMute : ui.mobileUnmute}
          </button>
          <button type="button" className="active">
            {ui.mobileListening}
          </button>
        </div>
      </div>

      <p className="demo-note">{ui.mobileDemoNote}</p>
    </div>
  )
}
