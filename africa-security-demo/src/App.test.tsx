import { describe, expect, it, vi, afterEach, beforeEach } from 'vitest'
import { cleanup, render, screen, fireEvent, within } from '@testing-library/react'
import App from './App'
import DesktopApp from './DesktopApp'
import MobileApp from './mobile/MobileApp'
import { LocaleProvider } from './i18n/LocaleContext'
import {
  getAlerts,
  getArchitectureLayers,
  getCampMission,
  getDevices,
  getLinkageSteps,
  getVillaMission,
} from './data/mockData'
import { LOCALE_STORAGE_KEY } from './i18n/types'

vi.mock('./components/MapCanvas', () => ({
  MapCanvas: () => <div data-testid="map-canvas">map</div>,
}))

afterEach(() => {
  cleanup()
  localStorage.removeItem(LOCALE_STORAGE_KEY)
})

beforeEach(() => {
  window.history.replaceState({}, '', '/?view=desktop')
})

function renderDesktop() {
  const view = render(
    <LocaleProvider>
      <DesktopApp />
    </LocaleProvider>,
  )
  const root = screen.getByTestId('africa-security-demo')
  return { ...view, root }
}

function renderMobile() {
  const view = render(
    <LocaleProvider>
      <MobileApp />
    </LocaleProvider>,
  )
  const root = screen.getByTestId('mobile-app')
  return { ...view, root }
}

describe('Desktop console', () => {
  it('renders platform title and command layout', () => {
    const { root } = renderDesktop()
    expect(within(root).getByText('非洲安防空地一体综合管理平台')).toBeInTheDocument()
    expect(within(root).getByText(/Africa Air-Ground Integrated Security Platform/i)).toBeInTheDocument()
    expect(within(root).getByTestId('left-panel')).toBeInTheDocument()
    expect(within(root).getByTestId('right-panel')).toBeInTheDocument()
    expect(within(root).getByTestId('map-canvas')).toBeInTheDocument()
  })

  it('shows camp mission data by default', () => {
    const { root } = renderDesktop()
    const campMission = getCampMission('zh')
    const alerts = getAlerts('zh')
    expect(within(root).getByText(campMission.name)).toBeInTheDocument()
    expect(within(root).getAllByText(campMission.routeName).length).toBeGreaterThan(0)
    expect(within(root).getAllByText(alerts[0].name).length).toBeGreaterThan(0)
  })

  it('switches to villa scene and updates selected alert', () => {
    const { root } = renderDesktop()
    fireEvent.click(within(root).getByRole('button', { name: '高端别墅' }))
    expect(within(root).getByText(getVillaMission('zh').name)).toBeInTheDocument()
    expect(within(root).getAllByText('别墅门口黄金5分钟风险').length).toBeGreaterThan(0)
  })

  it('opens alert list and filters pending items', () => {
    const { root } = renderDesktop()
    fireEvent.click(within(root).getByRole('tab', { name: '预警线索' }))
    const alertsView = within(root).getByTestId('alerts-view')
    fireEvent.click(within(alertsView).getByRole('button', { name: '待处理' }))
    const pending = getAlerts('zh').filter((a) => a.scene === 'camp' && a.status === 'pending')
    for (const item of pending) {
      expect(within(alertsView).getByText(item.name)).toBeInTheDocument()
    }
  })

  it('shows devices and linkage workflow content', () => {
    const { root } = renderDesktop()
    fireEvent.click(within(root).getByRole('tab', { name: '设备' }))
    expect(within(root).getByText(getDevices('zh')[0].name)).toBeInTheDocument()

    fireEvent.click(within(root).getByRole('tab', { name: '空地联动' }))
    expect(within(root).getByText(getLinkageSteps('zh')[0].title)).toBeInTheDocument()

    fireEvent.click(within(root).getByRole('tab', { name: '五层架构' }))
    expect(within(root).getByText(getArchitectureLayers('zh')[0].name)).toBeInTheDocument()
  })

  it('updates alert processing status from left panel', () => {
    const { root } = renderDesktop()
    const left = within(root).getByTestId('left-panel')
    const select = within(left).getByLabelText('处理状态') as HTMLSelectElement
    fireEvent.change(select, { target: { value: 'processing' } })
    expect(select.value).toBe('processing')
  })

  it('switches UI and content to English', () => {
    const { root } = renderDesktop()
    fireEvent.click(within(root).getByRole('button', { name: 'EN' }))
    expect(root).toHaveAttribute('data-locale', 'en')
    expect(within(root).getByRole('heading', { level: 1 })).toHaveTextContent(
      'Africa Air-Ground Integrated Security Platform',
    )
    expect(within(root).getByText(getCampMission('en').name)).toBeInTheDocument()
    expect(within(root).getAllByText(getAlerts('en')[0].name).length).toBeGreaterThan(0)
  })
})

describe('Mobile app live + intercom', () => {
  it('opens live view with drone and robot dog feeds', () => {
    const { root } = renderMobile()
    expect(within(root).getByTestId('mobile-live')).toBeInTheDocument()
    expect(within(root).getByTestId('video-stage')).toBeInTheDocument()
    const dogFeed = within(root).getByTestId('feed-RD-01-optical')
    expect(dogFeed).toBeInTheDocument()
    expect(dogFeed.querySelector('img.video-stream')).toHaveAttribute(
      'src',
      '/feeds/robot-dog-live.gif',
    )
    fireEvent.click(within(root).getByRole('button', { name: /无人机|Drone/i }))
    expect(within(root).getByTestId('feed-UAV-01-optical')).toBeInTheDocument()
  })

  it('supports hold-to-talk intercom transcript', () => {
    const { root } = renderMobile()
    const ptt = within(root).getByTestId('ptt-button')
    fireEvent.pointerDown(ptt)
    expect(ptt).toHaveAttribute('aria-pressed', 'true')
    fireEvent.pointerUp(ptt)
    const log = within(root).getByTestId('chat-log')
    expect(log.querySelector('.chat-item.you')).toBeTruthy()
    expect(within(log).queryByText(/暂无对讲记录|No intercom yet/i)).not.toBeInTheDocument()
  })

  it('can switch to alerts and devices tabs', () => {
    const { root } = renderMobile()
    const tabbar = within(root).getByRole('navigation')
    fireEvent.click(within(tabbar).getByText('告警'))
    expect(within(root).getByTestId('mobile-alerts')).toBeInTheDocument()
    fireEvent.click(within(tabbar).getByText('设备'))
    expect(within(root).getByTestId('mobile-devices')).toBeInTheDocument()
    expect(within(root).getByText(getDevices('zh')[0].name)).toBeInTheDocument()
  })
})

describe('App mode switcher', () => {
  it('switches from desktop to mobile shell', () => {
    render(
      <LocaleProvider>
        <App />
      </LocaleProvider>,
    )
    expect(screen.getByTestId('africa-security-demo')).toBeInTheDocument()
    fireEvent.click(screen.getByTestId('switch-mobile'))
    expect(screen.getByTestId('mobile-app')).toBeInTheDocument()
  })
})

describe('mock data assumptions', () => {
  it('covers air-ground assets and African POC scenes in both locales', () => {
    for (const locale of ['zh', 'en'] as const) {
      const devices = getDevices(locale)
      const alerts = getAlerts(locale)
      expect(devices.some((d) => d.type === 'drone')).toBe(true)
      expect(devices.some((d) => d.type === 'robotDog')).toBe(true)
      expect(alerts.some((a) => a.scene === 'camp')).toBe(true)
      expect(getLinkageSteps(locale)).toHaveLength(6)
      expect(getArchitectureLayers(locale)).toHaveLength(5)
    }
  })
})
