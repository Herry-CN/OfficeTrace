import { describe, expect, it, vi, afterEach } from 'vitest'
import { cleanup, render, screen, fireEvent, within } from '@testing-library/react'
import App from './App'
import { alerts, campMission, devices, linkageSteps, architectureLayers } from './data/mockData'

vi.mock('./components/MapCanvas', () => ({
  MapCanvas: () => <div data-testid="map-canvas">map</div>,
}))

afterEach(() => {
  cleanup()
})

function renderApp() {
  const view = render(<App />)
  const root = screen.getByTestId('africa-security-demo')
  return { ...view, root }
}

describe('Africa security demo', () => {
  it('renders platform title and command layout', () => {
    const { root } = renderApp()
    expect(within(root).getByText('非洲安防空地一体综合管理平台')).toBeInTheDocument()
    expect(within(root).getByText(/Africa Air-Ground Integrated Security Platform/i)).toBeInTheDocument()
    expect(within(root).getByTestId('left-panel')).toBeInTheDocument()
    expect(within(root).getByTestId('right-panel')).toBeInTheDocument()
    expect(within(root).getByTestId('map-canvas')).toBeInTheDocument()
  })

  it('shows camp mission data by default', () => {
    const { root } = renderApp()
    expect(within(root).getByText(campMission.name)).toBeInTheDocument()
    expect(within(root).getAllByText(campMission.routeName).length).toBeGreaterThan(0)
    expect(within(root).getAllByText(alerts[0].name).length).toBeGreaterThan(0)
  })

  it('switches to villa scene and updates selected alert', () => {
    const { root } = renderApp()
    fireEvent.click(within(root).getByRole('button', { name: '高端别墅' }))
    expect(within(root).getByText('别墅区 · 夜间静音巡逻')).toBeInTheDocument()
    expect(within(root).getAllByText('别墅门口黄金5分钟风险').length).toBeGreaterThan(0)
  })

  it('opens alert list and filters pending items', () => {
    const { root } = renderApp()
    fireEvent.click(within(root).getByRole('tab', { name: '预警线索' }))
    const alertsView = within(root).getByTestId('alerts-view')
    expect(alertsView).toBeInTheDocument()
    fireEvent.click(within(alertsView).getByRole('button', { name: '待处理' }))
    const pending = alerts.filter((a) => a.scene === 'camp' && a.status === 'pending')
    for (const item of pending) {
      expect(within(alertsView).getByText(item.name)).toBeInTheDocument()
    }
  })

  it('shows devices and linkage workflow content', () => {
    const { root } = renderApp()
    fireEvent.click(within(root).getByRole('tab', { name: '设备' }))
    expect(within(root).getByTestId('devices-view')).toBeInTheDocument()
    expect(within(root).getByText(devices[0].name)).toBeInTheDocument()

    fireEvent.click(within(root).getByRole('tab', { name: '空地联动' }))
    expect(within(root).getByTestId('linkage-view')).toBeInTheDocument()
    expect(within(root).getByText(linkageSteps[0].title)).toBeInTheDocument()

    fireEvent.click(within(root).getByRole('tab', { name: '五层架构' }))
    expect(within(root).getByTestId('architecture-view')).toBeInTheDocument()
    expect(within(root).getByText(architectureLayers[0].name)).toBeInTheDocument()
  })

  it('updates alert processing status from left panel', () => {
    const { root } = renderApp()
    const left = within(root).getByTestId('left-panel')
    const select = within(left).getByLabelText('处理状态') as HTMLSelectElement
    fireEvent.change(select, { target: { value: 'processing' } })
    expect(select.value).toBe('processing')
  })
})

describe('mock data assumptions', () => {
  it('covers air-ground assets and African POC scenes', () => {
    expect(devices.some((d) => d.type === 'drone')).toBe(true)
    expect(devices.some((d) => d.type === 'robotDog')).toBe(true)
    expect(devices.some((d) => d.type === 'starlink')).toBe(true)
    expect(alerts.some((a) => a.scene === 'camp')).toBe(true)
    expect(alerts.some((a) => a.scene === 'villa')).toBe(true)
    expect(linkageSteps).toHaveLength(6)
    expect(architectureLayers).toHaveLength(5)
  })
})
