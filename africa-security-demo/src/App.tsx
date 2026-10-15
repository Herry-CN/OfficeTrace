import { useEffect, useState } from 'react'
import DesktopApp from './DesktopApp'
import MobileApp from './mobile/MobileApp'
import { useLocale } from './i18n/LocaleContext'
import './mobile/mobile.css'

type AppMode = 'desktop' | 'mobile'

function readMode(): AppMode {
  const params = new URLSearchParams(window.location.search)
  if (params.get('view') === 'mobile') return 'mobile'
  if (params.get('view') === 'desktop') return 'desktop'
  if (window.matchMedia('(max-width: 768px)').matches) return 'mobile'
  return 'desktop'
}

export default function App() {
  const { ui } = useLocale()
  const [mode, setMode] = useState<AppMode>(() => readMode())

  useEffect(() => {
    const url = new URL(window.location.href)
    url.searchParams.set('view', mode)
    window.history.replaceState({}, '', url)
  }, [mode])

  return (
    <>
      <div className="mode-switcher" role="group" aria-label="app-mode">
        <button
          type="button"
          className={mode === 'desktop' ? 'active' : ''}
          onClick={() => setMode('desktop')}
        >
          {ui.viewDesktop}
        </button>
        <button
          type="button"
          className={mode === 'mobile' ? 'active' : ''}
          onClick={() => setMode('mobile')}
          data-testid="switch-mobile"
        >
          {ui.viewMobile}
        </button>
      </div>
      {mode === 'desktop' ? <DesktopApp /> : <MobileApp />}
    </>
  )
}
